const Renderer3D = @This();

const std = @import("std");
const window = @import("../windowing/window.zig");
const graphics = @import("../graphics.zig");
const GraphicsContext = graphics.Context;
const Image = graphics.Image;
const Sampler = graphics.Sampler;
const vk = graphics.vulkan;
const zalgebra = @import("zalgebra");

const cull_comp_spv = @alignCast(4, @embedFile("spirv/cull.comp.spv"));

const tri_vert_spv = @alignCast(4, @embedFile("spirv/tri.vert.spv"));
const tri_frag_spv = @alignCast(4, @embedFile("spirv/tri.frag.spv"));

const depth_vert_spv = @alignCast(4, @embedFile("spirv/depth.vert.spv"));
const depth_frag_spv = @alignCast(4, @embedFile("spirv/depth.frag.spv"));

const ColorPassPushConstants = extern struct 
{
    view_projection: [4][4]f32,
};

const DrawCullPushConstants = extern struct 
{
    draw_count: u32,
    near_face: [4]f32,
    far_face: [4]f32,
    right_face: [4]f32,
    left_face: [4]f32,
    top_face: [4]f32,
    bottom_face: [4]f32,
};

const InputDraw = extern struct 
{
    mesh_index: u32,
};

const DrawCommand = extern struct 
{
    indirect_command: graphics.CommandBuffer.DrawIndexedIndirectCommand,
    instance_index: u32,
};

pub var self: Renderer3D = undefined;

allocator: std.mem.Allocator,
swapchain: *graphics.Swapchain,
depth_image: graphics.Image,
command_buffers: []graphics.CommandBuffer, 
frame_fence: graphics.Fence,

vertex_position_buffer: graphics.Buffer,
vertex_position_offset: usize,
vertex_buffer: graphics.Buffer,
vertex_offset: usize,
index_buffer: graphics.Buffer,
index_offset: usize,

cull_pipeline: graphics.ComputePipeline,
depth_pipeline: graphics.GraphicsPipeline,
color_pipeline: graphics.GraphicsPipeline,

draw_indirect_buffer: graphics.Buffer,
draw_indirect_count_buffer: graphics.Buffer,
draw_index: u32,

meshes: std.ArrayListUnmanaged(Mesh),
mesh_buffer: graphics.Buffer,

mesh_lods: std.ArrayListUnmanaged(MeshLod),
mesh_lod_buffer: graphics.Buffer,

transforms: [][4][3]f32,
transforms_buffer: graphics.Buffer,

material_indices: []u32,
material_indices_buffer: graphics.Buffer,

materials: std.ArrayListUnmanaged(Material),
materials_buffer: graphics.Buffer,

input_draws: []InputDraw,
input_draw_buffer: graphics.Buffer,

albedo_images: std.ArrayListUnmanaged(Image),
albedo_samplers: std.ArrayListUnmanaged(Sampler),

camera: Camera,

mesh_data_changed: bool,
material_data_changed: bool,

pub fn init(
    allocator: std.mem.Allocator,
    swapchain: *graphics.Swapchain
) !void 
{
    self.allocator = allocator;
    self.swapchain = swapchain;
    self.draw_index = 0;
    self.vertex_offset = 0;
    self.index_offset = 0;
    self.vertex_position_offset = 0;
    self.mesh_data_changed = false;
    self.material_data_changed = false;

    self.depth_image = try Image.init(window.getWidth(), window.getHeight(), 1, vk.Format.d32_sfloat, vk.ImageLayout.attachment_optimal);
    errdefer self.depth_image.deinit();

    self.command_buffers = try allocator.alloc(graphics.CommandBuffer, swapchain.swap_images.len);
    errdefer allocator.free(self.command_buffers);

    self.materials = .{};
    self.albedo_images = .{};
    self.albedo_samplers = .{};

    for (self.command_buffers) |*command_buffer|
    {
        command_buffer.* = try graphics.CommandBuffer.init(.graphics);
    }

    errdefer for (self.command_buffers) |*command_buffer|
    {
        command_buffer.deinit();
    };

    self.frame_fence = try graphics.Fence.init();
    errdefer self.frame_fence.deinit();

    const command_count = 4096 * 32;

    self.draw_indirect_buffer = try graphics.Buffer.init(command_count * @sizeOf(DrawCommand), .indirect_draw);
    errdefer self.draw_indirect_buffer.deinit();

    self.draw_indirect_count_buffer = try graphics.Buffer.init(@sizeOf(u32), .indirect_draw);
    errdefer self.draw_indirect_count_buffer.deinit();

    self.input_draw_buffer = try graphics.Buffer.init(command_count * @sizeOf(InputDraw), .storage);
    errdefer self.input_draw_buffer.deinit();

    self.input_draws = try self.input_draw_buffer.map(InputDraw);

    self.mesh_buffer = try graphics.Buffer.init(4096, .storage);
    errdefer self.mesh_buffer.deinit();

    self.mesh_lod_buffer = try graphics.Buffer.init(4096 * 4, .storage);
    errdefer self.mesh_lod_buffer.deinit();

    const vertex_buffer_size = 32 * 1024 * 1024;

    self.vertex_position_buffer = try graphics.Buffer.init(vertex_buffer_size, .vertex);
    errdefer self.vertex_position_buffer.deinit();

    self.vertex_buffer = try graphics.Buffer.init(vertex_buffer_size, .vertex);
    errdefer self.vertex_buffer.deinit();

    self.index_buffer = try graphics.Buffer.init(vertex_buffer_size, .index);
    errdefer self.index_buffer.deinit();

    self.cull_pipeline = try graphics.ComputePipeline.init(
        self.allocator, 
        cull_comp_spv, 
        .@"1d",
        null,
        DrawCullPushConstants
    );
    errdefer self.cull_pipeline.deinit(self.allocator);

    self.color_pipeline = try graphics.GraphicsPipeline.init(
        self.allocator,
        .{
            .color_attachment_formats = &[_]vk.Format 
            {
                swapchain.surface_format.format,
            },
            .depth_attachment_format = self.depth_image.format,
            .vertex_shader_binary = tri_vert_spv,
            .fragment_shader_binary = tri_frag_spv,
            .depth_state = .{
                .write_enabled = false,
                .test_enabled = true,
                .compare_op = .greater_or_equal,
            },
        },
        null,
        ColorPassPushConstants,
    );
    errdefer self.color_pipeline.deinit(allocator);

    self.depth_pipeline = try graphics.GraphicsPipeline.init(
        self.allocator,
        .{
            .color_attachment_formats = &.{},
            .depth_attachment_format = self.depth_image.format,
            .vertex_shader_binary = depth_vert_spv,
            .fragment_shader_binary = depth_frag_spv,
            .depth_state = .{
                .write_enabled = true,
                .test_enabled = true,
                .compare_op = .greater,
            },
        },
        null,
        ColorPassPushConstants,
    );
    errdefer self.depth_pipeline.deinit(allocator);

    self.transforms_buffer = try graphics.Buffer.init(command_count * @sizeOf([4][3]f32), .storage);
    errdefer self.transforms_buffer.deinit();

    self.transforms = try self.transforms_buffer.map([4][3]f32);

    self.material_indices_buffer = try graphics.Buffer.init(command_count * @sizeOf(u32), .storage);
    errdefer self.material_indices_buffer.deinit();

    self.material_indices = try self.material_indices_buffer.map(u32);

    self.materials_buffer = try graphics.Buffer.init(command_count * @sizeOf(Material), .storage);
    errdefer self.materials_buffer.deinit();

    self.color_pipeline.setDescriptorBuffer(0, 0, self.vertex_position_buffer);
    self.color_pipeline.setDescriptorBuffer(1, 0, self.vertex_buffer);
    self.color_pipeline.setDescriptorBuffer(2, 0, self.transforms_buffer);
    self.color_pipeline.setDescriptorBuffer(3, 0, self.material_indices_buffer);
    self.color_pipeline.setDescriptorBuffer(4, 0, self.draw_indirect_buffer);
    self.color_pipeline.setDescriptorBuffer(5, 0, self.materials_buffer);

    self.depth_pipeline.setDescriptorBuffer(0, 0, self.vertex_position_buffer);
    self.depth_pipeline.setDescriptorBuffer(1, 0, self.transforms_buffer);
    self.depth_pipeline.setDescriptorBuffer(2, 0, self.draw_indirect_buffer);

    self.cull_pipeline.setDescriptorBuffer(0, 0, self.transforms_buffer);
    self.cull_pipeline.setDescriptorBuffer(1, 0, self.mesh_buffer);
    self.cull_pipeline.setDescriptorBuffer(2, 0, self.mesh_lod_buffer);
    self.cull_pipeline.setDescriptorBuffer(3, 0, self.draw_indirect_buffer);
    self.cull_pipeline.setDescriptorBuffer(4, 0, self.draw_indirect_count_buffer);
    self.cull_pipeline.setDescriptorBuffer(5, 0, self.input_draw_buffer);
}

pub fn deinit() void 
{
    defer self = undefined;
    defer self.allocator.free(self.command_buffers);
    defer self.depth_image.deinit();
    defer for (self.command_buffers) |*command_buffer|
    {
        command_buffer.deinit();
    };
    defer self.frame_fence.deinit();
    defer self.draw_indirect_buffer.deinit();
    defer self.draw_indirect_count_buffer.deinit();
    defer self.input_draw_buffer.deinit();
    defer self.mesh_buffer.deinit();
    defer self.mesh_lod_buffer.deinit();
    defer self.vertex_position_buffer.deinit();
    defer self.vertex_buffer.deinit();
    defer self.index_buffer.deinit();
    defer self.cull_pipeline.deinit(self.allocator);
    defer self.depth_pipeline.deinit(self.allocator);
    defer self.color_pipeline.deinit(self.allocator);
    defer self.meshes.deinit(self.allocator);
    defer self.mesh_lods.deinit(self.allocator);
    defer self.transforms_buffer.deinit();
    defer self.material_indices_buffer.deinit();
    defer self.materials.deinit(self.allocator);
    defer self.materials_buffer.deinit();
    defer self.albedo_images.deinit(self.allocator);
    defer for (self.albedo_images.items) |*image|
    {
        image.deinit();
    };
    defer self.albedo_samplers.deinit(self.allocator);
    defer for (self.albedo_samplers.items) |*sampler|
    {
        sampler.deinit();
    };
}

pub const Camera = struct 
{
    translation: [3]f32,
    target: [3]f32,
    fov: f32,
};

pub fn beginRender(camera: Camera) void 
{
    self.draw_index = 0;
    self.camera = camera;
}

fn perspectiveProjection(fovy_degrees: f32, aspect_ratio: f32, znear: f32) zalgebra.Mat4 
{
    const f = 1 / std.math.tan(std.math.degreesToRadians(f32, fovy_degrees) / 2);

    return .{
        .data = .{
            .{ f / aspect_ratio, 0, 0, 0 },
            .{ 0, f, 0, 0 },
            .{ 0, 0, 0, -1 },
            .{ 0, 0, znear, 0 },
        },
    };
}

fn vectorLength(p: @Vector(4, f32)) f32
{
    return @sqrt(@reduce(.Add, p * p));
}

fn vectorCross(a: @Vector(3, f32), b: @Vector(3, f32)) @Vector(3, f32)
{
    const x1 = a[0];
    const y1 = a[1];
    const z1 = a[2];

    const x2 = b[0];
    const y2 = b[1];
    const z2 = b[2];

    const result_x = (y1 * z2) - (z1 * y2);
    const result_y = (z1 * x2) - (x1 * z2);
    const result_z = (x1 * y2) - (y1 * x2);

    return @Vector(3, f32) { result_x, result_y, result_z };
}

fn normalizePlane(p: @Vector(4, f32)) @Vector(4, f32) 
{
    return p / @splat(4, vectorLength(.{ p[0], p[1], p[2], 0 }));
}

fn extractPlanesFromProjmat(
        proj: [4][4]f32,
        view: [4][4]f32,
        left: *[4]f32, right: *[4]f32,
        bottom: *[4]f32, top: *[4]f32,
        near: *[4]f32, far: *[4]f32) void
{
    const mat = zalgebra.Mat4.mul(zalgebra.Mat4 { .data = proj }, zalgebra.Mat4.transpose(.{ .data = view })).data;

    var i: usize = 0;

    i = 3;
    while (i > 0) : (i -= 1) left[i]   = mat[i][3] + mat[i][0];
    i = 3;
    while (i > 0) : (i -= 1) right[i]  = mat[i][3] - mat[i][0];
    i = 3;
    while (i > 0) : (i -= 1) bottom[i] = mat[i][3] + mat[i][1];
    i = 3;
    while (i > 0) : (i -= 1) top[i]    = mat[i][3] - mat[i][1];
    i = 3;
    while (i > 0) : (i -= 1) near[i]   = mat[i][3] + mat[i][2];
    i = 3;
    while (i > 0) : (i -= 1) far[i]    = mat[i][3] - mat[i][2];
}

fn createPlane(p1: @Vector(3, f32), normal: @Vector(3, f32)) [4]f32
{
    const normalized_normal = zalgebra.Vec3.norm(.{ .data = normal }).data;
    const distance = zalgebra.Vec3.dot(.{ .data = normalized_normal }, .{ .data = p1 });

    return .{ normalized_normal[0], normalized_normal[1], normalized_normal[2], distance };
}

pub fn endRender() void 
{
    endRenderInternal() catch unreachable;
}

fn endRenderInternal() !void
{
    const image_index = self.swapchain.image_index;
    const image = self.swapchain.swap_images[image_index];
    const command_buffer = &self.command_buffers[image_index];

    if (self.mesh_data_changed)
    {
        try self.mesh_buffer.update(Mesh, 0, self.meshes.items);
        try self.mesh_lod_buffer.update(MeshLod, 0, self.mesh_lods.items);

        self.mesh_data_changed = false;
    }

    if (self.material_data_changed)
    {
        try self.materials_buffer.update(Material, 0, self.materials.items);

        self.material_data_changed = false;
    }

    const aspect_ratio: f32 = @intToFloat(f32, window.getWidth()) / @intToFloat(f32, window.getHeight());  
    const near_plane: f32 = 0.01;
    const far_plane: f32 = 1000;

    _ = far_plane;

    const fov: f32 = self.camera.fov;
    const projection = perspectiveProjection(fov, aspect_ratio, near_plane);
    const view_projection = projection.mul(
        zalgebra.lookAt(
            .{ .data = self.camera.translation }, 
            .{ .data = self.camera.target }, 
            .{ .data = .{ 0, -1, 0 } }
        )
    );

    {
        command_buffer.begin() catch unreachable;
        defer command_buffer.end();

        //compute pass #1 pre depth cull
        {
            GraphicsContext.self.vkd.cmdPipelineBarrier2(
                command_buffer.handle, 
                &.{
                    .dependency_flags = .{ .by_region_bit = true, },
                    .memory_barrier_count = 0,
                    .p_memory_barriers = undefined,
                    .buffer_memory_barrier_count = 0,
                    .p_buffer_memory_barriers = undefined,
                    .image_memory_barrier_count = 1,
                    .p_image_memory_barriers = @ptrCast([*]const vk.ImageMemoryBarrier2, &vk.ImageMemoryBarrier2
                    {
                        .src_stage_mask = .{ .all_commands_bit = true },
                        .src_access_mask = .{},
                        .dst_stage_mask = .{ .color_attachment_output_bit = true },
                        .dst_access_mask = .{ .color_attachment_write_bit = true },
                        .old_layout = .@"undefined",
                        .new_layout = .attachment_optimal,
                        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                        .image = image.image,
                        .subresource_range = .{
                            .aspect_mask = .{ .color_bit = true },
                            .base_mip_level = 0,
                            .level_count = vk.REMAINING_MIP_LEVELS,
                            .base_array_layer = 0,
                            .layer_count = vk.REMAINING_ARRAY_LAYERS,
                        },
                    }),
                }
            );

            GraphicsContext.self.vkd.cmdPipelineBarrier2(
                command_buffer.handle, 
                &.{
                    .dependency_flags = .{ .by_region_bit = true, },
                    .memory_barrier_count = 0,
                    .p_memory_barriers = undefined,
                    .buffer_memory_barrier_count = 0,
                    .p_buffer_memory_barriers = undefined,
                    .image_memory_barrier_count = 1,
                    .p_image_memory_barriers = @ptrCast([*]const vk.ImageMemoryBarrier2, &vk.ImageMemoryBarrier2
                    {
                        .src_stage_mask = .{ .all_commands_bit = true },
                        .src_access_mask = .{},
                        .dst_stage_mask = .{ .color_attachment_output_bit = true },
                        .dst_access_mask = .{ .color_attachment_write_bit = true },
                        .old_layout = .@"undefined",
                        .new_layout = .attachment_optimal,
                        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                        .image = self.depth_image.handle,
                        .subresource_range = .{
                            .aspect_mask = .{ .depth_bit = true },
                            .base_mip_level = 0,
                            .level_count = vk.REMAINING_MIP_LEVELS,
                            .base_array_layer = 0,
                            .layer_count = vk.REMAINING_ARRAY_LAYERS,
                        },
                    }),
                }
            );

            command_buffer.setComputePipeline(self.cull_pipeline);
            
            command_buffer.fillBuffer(self.draw_indirect_count_buffer, 0, @sizeOf(u32), 0);

            GraphicsContext.self.vkd.cmdPipelineBarrier2(
                command_buffer.handle, 
                &.{
                    .dependency_flags = .{ .by_region_bit = true, },
                    .memory_barrier_count = 0,
                    .p_memory_barriers = undefined,
                    .buffer_memory_barrier_count = 1,
                    .p_buffer_memory_barriers = &[_]vk.BufferMemoryBarrier2
                    {
                        .{
                            .src_stage_mask = .{ .copy_bit = true },
                            .src_access_mask = .{ .transfer_write_bit = true },
                            .dst_stage_mask = .{ .compute_shader_bit = true, },
                            .dst_access_mask = .{ .shader_read_bit = true, .shader_write_bit = true },
                            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                            .buffer = self.draw_indirect_count_buffer.handle,
                            .offset = 0,
                            .size = self.draw_indirect_count_buffer.size,
                        }
                    },
                    .image_memory_barrier_count = 0,
                    .p_image_memory_barriers = undefined,
                }
            );

            var near_face: [4]f32 = .{ 0, 0, 0, 0 };
            var far_face: [4]f32 = .{ 0, 0, 0, 0 };
            var right_face: [4]f32 = .{ 0, 0, 0, 0 };
            var left_face: [4]f32 = .{ 0, 0, 0, 0 };
            var top_face: [4]f32 = .{ 0, 0, 0, 0 };
            var bottom_face: [4]f32 = .{ 0, 0, 0, 0 };

            // extractPlanesFromProjmat(view_projection.data, view_projection.data, &left_face, &right_face, &bottom_face, &top_face, &near_face, &far_face);

            const front = @as(@Vector(3, f32), self.camera.target) - @as(@Vector(3, f32), self.camera.translation);

            near_face = createPlane(self.camera.translation + (@splat(3, near_plane) * front), front);

            command_buffer.setPushData(DrawCullPushConstants, .{ 
                .draw_count = self.draw_index,
                .near_face = near_face,
                .far_face = far_face,
                .right_face = right_face,
                .left_face = left_face,
                .top_face = top_face,
                .bottom_face = bottom_face,
            });
            command_buffer.computeDispatch(self.draw_index, 1, 1);

            GraphicsContext.self.vkd.cmdPipelineBarrier2(
                command_buffer.handle, 
                &.{
                    .dependency_flags = .{ .by_region_bit = true, },
                    .memory_barrier_count = 0,
                    .p_memory_barriers = undefined,
                    .buffer_memory_barrier_count = 2,
                    .p_buffer_memory_barriers = &[_]vk.BufferMemoryBarrier2
                    {
                        .{
                            .src_stage_mask = .{ .compute_shader_bit = true },
                            .src_access_mask = .{ .shader_write_bit = true },
                            .dst_stage_mask = .{ .draw_indirect_bit = true, .vertex_shader_bit = true }, //vk.PipelineStageFlags2
                            .dst_access_mask = .{ .indirect_command_read_bit = true, .shader_read_bit = true },
                            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                            .buffer = self.draw_indirect_buffer.handle,
                            .offset = 0,
                            .size = self.draw_indirect_buffer.size,
                        },
                        .{
                            .src_stage_mask = .{ .compute_shader_bit = true },
                            .src_access_mask = .{ .shader_write_bit = true },
                            .dst_stage_mask = .{ .draw_indirect_bit = true, },
                            .dst_access_mask = .{ .indirect_command_read_bit = true },
                            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                            .buffer = self.draw_indirect_count_buffer.handle,
                            .offset = 0,
                            .size = self.draw_indirect_count_buffer.size,
                        },
                    },
                    .image_memory_barrier_count = 0,
                    .p_image_memory_barriers = undefined,
                }
            );
        }

        //Depth pass #1
        {
            command_buffer.beginRenderPass(
                0, 
                0, 
                window.getWidth(), 
                window.getHeight(), 
                &.{},
                .{
                    .image = &self.depth_image,
                    .clear = .{ .depth = 0 },
                }
            );
            defer command_buffer.endRenderPass();

            command_buffer.setViewport(0, 0, @intToFloat(f32, window.getWidth()), @intToFloat(f32, window.getHeight()), 0, 1);
            command_buffer.setScissor(0, 0, window.getWidth(), window.getHeight());
            command_buffer.setGraphicsPipeline(self.depth_pipeline);
            command_buffer.setIndexBuffer(self.index_buffer, .u32);
            command_buffer.setPushData(ColorPassPushConstants, .{
                .view_projection = view_projection.data,
            });

            command_buffer.drawIndexedIndirectCount(
                self.draw_indirect_buffer, 
                0, 
                @sizeOf(DrawCommand),
                self.draw_indirect_count_buffer,
                0,
                self.draw_index
            );
        }

        GraphicsContext.self.vkd.cmdPipelineBarrier2(
            command_buffer.handle, 
            &.{
                .dependency_flags = .{ .by_region_bit = true, },
                .memory_barrier_count = 1,
                .p_memory_barriers = &[_]vk.MemoryBarrier2
                {
                    .{
                        .src_stage_mask = vk.PipelineStageFlags2 { .late_fragment_tests_bit = true, },
                        .src_access_mask = vk.AccessFlags2 { .depth_stencil_attachment_write_bit = true },
                        .dst_stage_mask = .{ .early_fragment_tests_bit = true,  },
                        .dst_access_mask = .{ .depth_stencil_attachment_read_bit = true, },
                    }
                },
                .buffer_memory_barrier_count = 0,
                .p_buffer_memory_barriers = undefined,
                .image_memory_barrier_count = 0,
                .p_image_memory_barriers = undefined,
            }
        );

        //Color pass #1
        {
            var color_image: Image = undefined;

            color_image.view = image.view;
            color_image.handle = image.image;

            command_buffer.beginRenderPass(
                0, 
                0, 
                window.getWidth(), 
                window.getHeight(), 
                &[_]graphics.CommandBuffer.Attachment {
                    .{
                        .image = &color_image,
                        .clear = .{ .color = .{ 0, 0, 0, 1 } }
                    }
                }, 
                .{
                    .image = &self.depth_image,
                    .clear = null,
                }
            );
            defer command_buffer.endRenderPass();

            command_buffer.setViewport(0, 0, @intToFloat(f32, window.getWidth()), @intToFloat(f32, window.getHeight()), 0, 1);
            command_buffer.setScissor(0, 0, window.getWidth(), window.getHeight());

            command_buffer.setGraphicsPipeline(self.color_pipeline);
            command_buffer.setIndexBuffer(self.index_buffer, .u32);
            command_buffer.setPushData(ColorPassPushConstants, .{
                .view_projection = view_projection.data,
            });

            command_buffer.drawIndexedIndirectCount(
                self.draw_indirect_buffer, 
                0, 
                @sizeOf(DrawCommand),
                self.draw_indirect_count_buffer,
                0,
                self.draw_index
            );
        }

        GraphicsContext.self.vkd.cmdPipelineBarrier2(
            command_buffer.handle, 
            &.{
                .dependency_flags = .{ .by_region_bit = true, },
                .memory_barrier_count = 0,
                .p_memory_barriers = undefined,
                .buffer_memory_barrier_count = 0,
                .p_buffer_memory_barriers = undefined,
                .image_memory_barrier_count = 1,
                .p_image_memory_barriers = @ptrCast([*]const vk.ImageMemoryBarrier2, &vk.ImageMemoryBarrier2
                {
                    .src_stage_mask = .{ .color_attachment_output_bit = true },
                    .src_access_mask = .{ .color_attachment_write_bit = true },
                    .dst_stage_mask = .{},
                    .dst_access_mask = .{},
                    .old_layout = .attachment_optimal,
                    .new_layout = .present_src_khr,
                    .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .image = image.image,
                    .subresource_range = .{
                        .aspect_mask = .{ .color_bit = true },
                        .base_mip_level = 0,
                        .level_count = vk.REMAINING_MIP_LEVELS,
                        .base_array_layer = 0,
                        .layer_count = vk.REMAINING_ARRAY_LAYERS,
                    },
                }),
            }
        );
    }

    try GraphicsContext.self.vkd.queueSubmit2(GraphicsContext.self.graphics_queue, 1, &[_]vk.SubmitInfo2
    {
        .{
            .flags = .{},
            .wait_semaphore_info_count = 1,
            .p_wait_semaphore_infos = &[_]vk.SemaphoreSubmitInfo 
            {
                .{
                    .semaphore = image.image_acquired,
                    .value = 0,
                    .stage_mask = .{
                        .color_attachment_output_bit = true,
                    },
                    .device_index = 0,
                }
            },
            .command_buffer_info_count = 1,
            .p_command_buffer_infos = &[_]vk.CommandBufferSubmitInfo {
                .{
                    .command_buffer = command_buffer.handle,
                    .device_mask = 0,
                }
            },
            .signal_semaphore_info_count = 1,
            .p_signal_semaphore_infos = &[_]vk.SemaphoreSubmitInfo 
            {
                .{
                    .semaphore = image.render_finished,
                    .value = 0,
                    .stage_mask = .{
                        .color_attachment_output_bit = true,
                    },
                    .device_index = 0,
                }
            },
        }
    }, self.frame_fence.handle);

    _ = try GraphicsContext.self.vkd.queuePresentKHR(GraphicsContext.self.graphics_queue, &.{.wait_semaphore_count = 1,
        .p_wait_semaphores = @ptrCast([*]const vk.Semaphore, &image.render_finished),
        .swapchain_count = 1,
        .p_swapchains = @ptrCast([*]const vk.SwapchainKHR, &self.swapchain.handle),
        .p_image_indices = @ptrCast([*]const u32, &image_index),
        .p_results = null,
    });

    const result = try GraphicsContext.self.vkd.acquireNextImageKHR(
        GraphicsContext.self.device,
        self.swapchain.handle,
        std.math.maxInt(u64),
        self.swapchain.next_image_acquired,
        .null_handle,
    );

    std.mem.swap(vk.Semaphore, &self.swapchain.swap_images[result.image_index].image_acquired, &self.swapchain.next_image_acquired);
    self.swapchain.image_index = result.image_index;

    self.frame_fence.wait();
    self.frame_fence.reset();
}

const Mesh = extern struct 
{
    vertex_offset: u32,
    vertex_count: u32,
    lod_offset: u32,
    lod_count: u32,
    bounding_box_center: [3]f32,
    bounding_box_extents: [3]f32,
};

const MeshLod = extern struct 
{
    index_offset: u32,
    index_count: u32,
};

pub const MeshHandle = enum(u32) { _ }; 

pub fn createMesh(
    vertex_positions: []const [3]f32,
    vertices: []const Vertex,
    indices: []const u32,
    bounding_box_min: @Vector(3, f32),
    bounding_box_max: @Vector(3, f32),
) !MeshHandle
{
    const mesh_handle = @intCast(u32, self.meshes.items.len);

    const lod_offset = @intCast(u32, self.mesh_lods.items.len);
    const lod_count = 1;

    try self.mesh_lods.append(self.allocator, .{
        .index_offset = @intCast(u32, self.index_offset),
        .index_count = @intCast(u32, indices.len),
    });

    const bounding_box_center = (bounding_box_max + bounding_box_min) / @splat(3, @as(f32, 2));
    const bounding_box_extents = @Vector(3, f32) { 
        bounding_box_max[0] - bounding_box_center[0], 
        bounding_box_max[1] - bounding_box_center[1], 
        bounding_box_max[2] - bounding_box_center[2], 
    };

    try self.meshes.append(self.allocator, .{
        .vertex_offset = @intCast(u32, self.vertex_position_offset),
        .vertex_count = @intCast(u32, vertices.len),
        .lod_offset  = lod_offset,
        .lod_count = lod_count,
        .bounding_box_center = bounding_box_center,
        .bounding_box_extents = bounding_box_extents,
    });

    try self.vertex_position_buffer.update([3]f32, self.vertex_position_offset * @sizeOf([3]f32), vertex_positions);
    self.vertex_position_offset += vertex_positions.len;

    try self.vertex_buffer.update(Vertex, self.vertex_offset * @sizeOf(Vertex), vertices);
    self.vertex_offset += vertices.len;

    try self.index_buffer.update(u32, self.index_offset * @sizeOf(u32), indices);
    self.index_offset += indices.len;

    self.mesh_data_changed = true;

    return @intToEnum(MeshHandle, mesh_handle);
}

const Material = extern struct 
{
    albedo_texture_index: u32,
    albedo_color: u32,
};

pub const MaterialHandle = enum(u32) { _ };

fn packUnorm4x8(v: [4]f32) u32
{
    const Unorm4x8 = packed struct(u32)
    {
        x: u8,
        y: u8,
        z: u8,
        w: u8,
    };

    const x = @floatToInt(u8, v[0] * @intToFloat(f32, std.math.maxInt(u8)));
    const y = @floatToInt(u8, v[1] * @intToFloat(f32, std.math.maxInt(u8)));
    const z = @floatToInt(u8, v[2] * @intToFloat(f32, std.math.maxInt(u8)));
    const w = @floatToInt(u8, v[3] * @intToFloat(f32, std.math.maxInt(u8)));

    return @bitCast(u32, Unorm4x8 {
        .x = x,
        .y = y,
        .z = z, 
        .w = w,
    });
}

pub fn createMaterial(
    albedo_texture_data: []const u8,
    albedo_texture_width: u32,
    albedo_texture_height: u32,
    albedo_color: [4]f32,
) !MaterialHandle 
{
    const material_handle = @intCast(u32, self.materials.items.len);

    var albedo_image = try Image.initData(
        albedo_texture_data, 
        albedo_texture_width, 
        albedo_texture_height, 
        1, 
        .r8g8b8a8_srgb, 
        vk.ImageLayout.shader_read_only_optimal
    );
    errdefer albedo_image.deinit();

    try self.albedo_images.append(self.allocator, albedo_image);

    var albedo_sampler = try Sampler.init();
    errdefer albedo_sampler.deinit();
    
    try self.albedo_samplers.append(self.allocator, albedo_sampler);

    std.log.debug("Created material {}", .{ material_handle });

    self.color_pipeline.setDescriptorImageSampler(6, material_handle, albedo_image, albedo_sampler);

    try self.materials.append(self.allocator, .{
        .albedo_texture_index = material_handle,
        .albedo_color = packUnorm4x8(albedo_color)
    });

    self.material_data_changed = true;

    return @intToEnum(MaterialHandle, material_handle);
}

pub const Vertex = extern struct 
{
    normal: [3]f32,
    color: u32,
    uv: [2]f32,
};

pub fn drawMesh(
    mesh: MeshHandle,
    material: MaterialHandle,
    transform: zalgebra.Mat4x4(f32),
) void 
{
    self.input_draws[self.draw_index] = .{
        .mesh_index = @enumToInt(mesh),
    };

    self.transforms[self.draw_index] = .{
        transform.data[0][0..3].*,
        transform.data[1][0..3].*,
        transform.data[2][0..3].*,
        transform.data[3][0..3].*,
    };

    self.material_indices[self.draw_index] = @enumToInt(material);

    self.draw_index += 1;
}