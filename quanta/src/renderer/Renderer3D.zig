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
const depth_reduce_comp_spv = @alignCast(4, @embedFile("spirv/depth_reduce.comp.spv"));

const tri_vert_spv = @alignCast(4, @embedFile("spirv/tri.vert.spv"));
const tri_frag_spv = @alignCast(4, @embedFile("spirv/tri.frag.spv"));

const depth_vert_spv = @alignCast(4, @embedFile("spirv/depth.vert.spv"));
const depth_frag_spv = @alignCast(4, @embedFile("spirv/depth.frag.spv"));

const ColorPassPushConstants = extern struct 
{
    view_projection: [4][4]f32,
};

const DepthReducePushData = extern struct 
{
    image_size: [2]f32,
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
depth_pyramid: graphics.Image,
depth_pyramid_levels: []Image.View,
depth_pyramid_level_count: u32,
command_buffers: []graphics.CommandBuffer, 
frame_fence: graphics.Fence,

transfer_command_buffer: graphics.CommandBuffer,
image_transfer_events: std.ArrayListUnmanaged(graphics.Event),

image_staging_buffers: std.ArrayListUnmanaged(graphics.Buffer),
image_staging_fence: graphics.Fence,

vertex_position_staging_buffers: std.ArrayListUnmanaged(graphics.Buffer),
vertex_staging_buffers: std.ArrayListUnmanaged(graphics.Buffer),
index_staging_buffers: std.ArrayListUnmanaged(graphics.Buffer),
mesh_staging_fence: graphics.Fence,

vertex_position_buffer: graphics.Buffer,
vertex_position_offset: usize,
vertex_buffer: graphics.Buffer,
vertex_offset: usize,
index_buffer: graphics.Buffer,
index_offset: usize,

depth_reduce_sampler: graphics.Sampler,

depth_reduce_pipeline: graphics.ComputePipeline,
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

fn previousPow2(v: u32) u32
{
	var r: u32 = 1;

	while (r * 2 < v)
		r *= 2;

	return r;
}

fn getImageMipLevels(width: u32, height: u32) u32
{
    var current_width = width;
    var current_height = height;

	var result: u32 = 1;

	while (current_width > 1 or current_height > 1)
	{
		result += 1;
		current_width /= 2;
		current_height /= 2;
	}

	return result;
}

fn initFrameImages(window_width: u32, window_height: u32) !void 
{
    const render_width = window_width;
    const render_height = window_height;

    self.depth_image = try Image.init(
        render_width, render_height, 1, 1,
        vk.Format.d32_sfloat, 
        vk.ImageLayout.attachment_optimal,
        .{  
            .depth_stencil_attachment_bit = true,
            .sampled_bit = true,
        }
    );
    errdefer self.depth_image.deinit();

    const depth_pyramid_width = previousPow2(render_width);
    const depth_pyramid_height = previousPow2(render_height);

    self.depth_pyramid_level_count = getImageMipLevels(depth_pyramid_width, depth_pyramid_height);

    self.depth_pyramid = try Image.init(
        depth_pyramid_width, depth_pyramid_height, 1,
        self.depth_pyramid_level_count,
        vk.Format.r32_sfloat, 
        .general,
        .{
            .transfer_src_bit = true, 
            .storage_bit = true, 
            .sampled_bit = true, 
        }
    );
    errdefer self.depth_pyramid.deinit();

    self.depth_pyramid_levels = try self.allocator.alloc(graphics.Image.View, self.depth_pyramid.levels);
    errdefer self.allocator.free(self.depth_pyramid_levels);

    for (self.depth_pyramid_levels) |*pyramid_level, i|
    {
        pyramid_level.* = try self.depth_pyramid.createView(@intCast(u32, i), 1);
    }

    errdefer for (self.depth_pyramid_levels) |*pyramid_level|
    {
        self.depth_pyramid.destroyView(pyramid_level);
    };
}

fn deinitFrameImages() void
{
    defer self.depth_image.deinit();
    defer self.depth_pyramid.deinit();
    defer self.allocator.free(self.depth_pyramid_levels);
    defer for (self.depth_pyramid_levels) |pyramid_level|
    {
        self.depth_pyramid.destroyView(pyramid_level);
    };
}

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
    self.image_transfer_events = .{}; 
    self.vertex_position_staging_buffers = .{};
    self.vertex_staging_buffers = .{};
    self.index_staging_buffers = .{};

    try initFrameImages(window.getWidth(), window.getHeight());
    errdefer deinitFrameImages();

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

    self.transfer_command_buffer = try graphics.CommandBuffer.init(.transfer);
    errdefer self.transfer_command_buffer.deinit();

    self.image_staging_buffers = .{};
    self.image_staging_fence = try graphics.Fence.init();
    errdefer self.image_staging_fence.deinit();

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

    self.depth_reduce_sampler = try graphics.Sampler.init(.nearest, .nearest, .min);
    errdefer self.depth_reduce_sampler.deinit();

    self.depth_reduce_pipeline = try graphics.ComputePipeline.init(
        self.allocator, 
        depth_reduce_comp_spv, 
        .@"2d",
        null,
        DepthReducePushData
    );
    errdefer self.depth_reduce_pipeline.deinit(self.allocator);

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
            .rasterisation_state = .{
                .polygon_mode = .line,
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
            .rasterisation_state = .{
                .polygon_mode = .fill,
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
    defer deinitFrameImages();
    defer for (self.command_buffers) |*command_buffer|
    {
        command_buffer.deinit();
    };
    defer self.image_staging_buffers.deinit(self.allocator);
    defer self.transfer_command_buffer.deinit();
    defer self.image_staging_fence.deinit();
    defer self.frame_fence.deinit();
    defer self.image_transfer_events.deinit(self.allocator);
    defer self.vertex_position_staging_buffers.deinit(self.allocator);
    defer self.vertex_staging_buffers.deinit(self.allocator);
    defer self.index_staging_buffers.deinit(self.allocator);
    defer self.draw_indirect_buffer.deinit();
    defer self.draw_indirect_count_buffer.deinit();
    defer self.input_draw_buffer.deinit();
    defer self.mesh_buffer.deinit();
    defer self.mesh_lod_buffer.deinit();
    defer self.vertex_position_buffer.deinit();
    defer self.vertex_buffer.deinit();
    defer self.index_buffer.deinit();
    defer self.depth_reduce_sampler.deinit();
    defer self.depth_reduce_pipeline.deinit(self.allocator);
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

pub fn beginRender(camera: Camera) !void 
{
    self.draw_index = 0;
    self.camera = camera;

    if (self.material_data_changed or self.mesh_data_changed)
    {
        {
            try self.transfer_command_buffer.begin();
            defer self.transfer_command_buffer.end();   

            if (self.mesh_data_changed)
            {
                try self.mesh_buffer.update(Mesh, 0, self.meshes.items);
                try self.mesh_lod_buffer.update(MeshLod, 0, self.mesh_lods.items);

                {
                    var offset: usize = 0;

                    for (self.vertex_position_staging_buffers.items) |staging_buffer|
                    {
                        self.transfer_command_buffer.copyBuffer(staging_buffer, 0, self.vertex_position_buffer, offset);

                        offset += staging_buffer.size;
                    }
                }

                {
                    var offset: usize = 0;

                    for (self.vertex_staging_buffers.items) |staging_buffer|
                    {
                        self.transfer_command_buffer.copyBuffer(staging_buffer, 0, self.vertex_buffer, offset);

                        offset += staging_buffer.size;
                    }
                }

                {
                    var offset: usize = 0;

                    for (self.index_staging_buffers.items) |staging_buffer|
                    {
                        self.transfer_command_buffer.copyBuffer(staging_buffer, 0, self.index_buffer, offset);

                        offset += staging_buffer.size;
                    }
                }

                self.mesh_data_changed = false;
            }

            if (self.material_data_changed) 
            {
                try self.materials_buffer.update(Material, 0, self.materials.items);

                for (self.image_staging_buffers.items) |staging_buffer, i|
                {
                    self.transfer_command_buffer.copyBufferToImage(staging_buffer, self.albedo_images.items[i]);

                    GraphicsContext.self.vkd.cmdSetEvent2(
                        self.transfer_command_buffer.handle, 
                        self.image_transfer_events.items[i].handle, 
                        &.{
                            .dependency_flags = .{},
                            .memory_barrier_count = 0,
                            .p_memory_barriers = undefined,
                            .buffer_memory_barrier_count = 0,
                            .p_buffer_memory_barriers = undefined,
                            .image_memory_barrier_count = 1,
                            .p_image_memory_barriers = &[_]vk.ImageMemoryBarrier2 
                            {
                                .{
                                    .src_stage_mask = .{
                                        .copy_bit = true,
                                    },
                                    .src_access_mask = .{
                                        .transfer_write_bit = true,
                                    },
                                    .dst_access_mask = .{},
                                    .dst_stage_mask = .{},
                                    .old_layout = .transfer_dst_optimal,
                                    .new_layout = self.albedo_images.items[i].layout,
                                    .src_queue_family_index = GraphicsContext.self.transfer_family_index.?,
                                    .dst_queue_family_index = GraphicsContext.self.graphics_family_index.?,
                                    .image = self.albedo_images.items[i].handle,
                                    .subresource_range = .{
                                        .aspect_mask = self.albedo_images.items[i].aspect_mask,
                                        .base_mip_level = 0,
                                        .level_count = vk.REMAINING_MIP_LEVELS,
                                        .base_array_layer = 0,
                                        .layer_count = vk.REMAINING_ARRAY_LAYERS,
                                    },
                                }
                            },
                        }
                    );
                }
        
                self.material_data_changed = false;
            }
        }

        self.image_staging_fence.reset();
        try self.transfer_command_buffer.submit(self.image_staging_fence);
    }
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
    if (self.image_staging_fence.getStatus() == true)
    {
        self.material_data_changed = false;
        self.mesh_data_changed = false;

        for (self.image_staging_buffers.items) |*staging_buffer|
        {
            staging_buffer.deinit();
        }
        self.image_staging_buffers.clearRetainingCapacity();

        for (self.image_transfer_events.items) |*event|
        {
            event.deinit();
        }
        self.image_transfer_events.clearRetainingCapacity();

        for (self.vertex_position_staging_buffers.items) |*staging|
        {
            staging.deinit();
        }
        self.vertex_position_staging_buffers.clearRetainingCapacity();

        for (self.vertex_staging_buffers.items) |*staging|
        {
            staging.deinit();
        }
        self.vertex_staging_buffers.clearRetainingCapacity();

        for (self.index_staging_buffers.items) |*staging|
        {
            staging.deinit();
        }
        self.index_staging_buffers.clearRetainingCapacity();
    }

    const image_index = self.swapchain.image_index;
    const image = self.swapchain.swap_images[image_index];
    const command_buffer = &self.command_buffers[image_index];

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
            .{ .data = .{ 0, -1, 0 } }, //May be problematic, we could flip the ndc clip space instead using vk_maintenence_4 
        )
    );

    //sneaky hack due to our incomplete swapchain abstraction
    var color_image: Image = undefined;

    color_image.view = image.view;
    color_image.handle = image.image;
    color_image.aspect_mask = .{ .color_bit = true };

    {
        command_buffer.begin() catch unreachable;
        defer command_buffer.end();

        //compute pass #1 pre depth per instance cull
        {

            command_buffer.setComputePipeline(self.cull_pipeline);
            
            command_buffer.fillBuffer(self.draw_indirect_count_buffer, 0, @sizeOf(u32), 0);

            command_buffer.bufferBarrier(self.draw_indirect_count_buffer, .{
                .source_stage = .{ .copy = true },
                .source_access = .{ .transfer_write = true },
                .destination_stage = .{ .compute_shader = true },
                .destination_access = .{ .shader_read = true, .shader_write = true },
            });

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

            command_buffer.bufferBarrier(self.draw_indirect_buffer, .{
                .source_stage = .{ .compute_shader = true },
                .source_access = .{ .shader_write = true },
                .destination_stage = .{ .draw_indirect = true, .vertex_shader = true },
                .destination_access = .{ .indirect_command_read = true, .shader_read = true },
            });
            command_buffer.bufferBarrier(self.draw_indirect_count_buffer, .{
                .source_stage = .{ .compute_shader = true },
                .source_access = .{ .shader_write = true },
                .destination_stage = .{ .draw_indirect = true },
                .destination_access = .{ .indirect_command_read = true },
            });
        }

        //Depth pass #1
        {
            command_buffer.imageBarrier(
                self.depth_image, 
                .{
                    .source_stage = .{ .all_commands = true },
                    .source_access = .{},
                    .destination_stage = .{ .color_attachment_output = true },
                    .destination_access = .{ .color_attachment_write = true },
                    .destination_layout = .attachment_optimal,
                }
            );

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

        //Depth reduce
        if (true)
        {
            command_buffer.imageBarrier(self.depth_image, .{
                .source_stage = .{ .late_fragment_tests = true },
                .source_access = .{ .depth_attachment_write = true },
                .source_layout = .attachment_optimal,
                .destination_stage = .{ .compute_shader = true },
                .destination_access = .{ .shader_read = true },
                .destination_layout = .shader_read_only_optimal,
            });

            command_buffer.imageBarrier(self.depth_pyramid, .{
                .source_stage = .{ .compute_shader = true },
                .source_access = .{ .shader_read = true },
                .source_layout = .general,
                .destination_stage = .{ .compute_shader = true },
                .destination_access = .{ .shader_write = true },
                .destination_layout = .general,
            });

            for (self.depth_pyramid_levels) |_, i|
            {
                const pyramid_level_width: u32 = @max(1, self.depth_pyramid.width >> @intCast(u5, i));
                const pyramid_level_height: u32 = @max(1, self.depth_pyramid.height >> @intCast(u5, i));

                if (i == 0)
                {
                    self.depth_reduce_pipeline.setDescriptorImageSampler(1, 0, self.depth_image, self.depth_reduce_sampler);
                }
                else 
                {
                    self.depth_reduce_pipeline.setDescriptorImageViewSampler(1, 0, self.depth_pyramid_levels[i - 1], self.depth_reduce_sampler);
                }

                self.depth_reduce_pipeline.setDescriptorImageView(0, 0, self.depth_pyramid_levels[i]);

                command_buffer.setComputePipeline(self.depth_reduce_pipeline);

                command_buffer.setPushData(DepthReducePushData, .{
                    .image_size = .{ @intToFloat(f32, pyramid_level_width), @intToFloat(f32, pyramid_level_height) }
                });
                command_buffer.computeDispatch(pyramid_level_width, pyramid_level_height, 1);

                command_buffer.imageBarrier(self.depth_pyramid, .{
                    .layer = @intCast(u32, i),
                    .source_stage = .{ .compute_shader = true },
                    .source_access = .{ .shader_write = true },
                    .source_layout = .general,
                    .destination_stage = .{ .compute_shader = true },
                    .destination_access = .{ .shader_read = true },
                    .destination_layout = .general,
                });
            }
        }

        // command_buffer.memoryBarrier(.{
        //     .source_stage = .{ .late_fragment_tests = true },
        //     .source_access = .{ .depth_attachment_write = true },
        //     .destination_stage = .{ .early_fragment_tests = true },
        //     .destination_access = .{ .depth_attachment_read = true },
        // });

        //Post depth per instance cull #1
        {
            
        }

        //Color pass #1
        {
            command_buffer.imageBarrier(color_image, .{
                .source_stage = .{ .all_commands = true },
                .source_access = .{},
                .destination_stage = .{ .color_attachment_output = true },
                .destination_access = .{ .color_attachment_write = true },
                .destination_layout = .attachment_optimal,
            });

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

        command_buffer.imageBarrier(color_image, .{
            .source_stage = .{ .color_attachment_output = true, },
            .source_access = .{  .color_attachment_write = true },
            .source_layout = .attachment_optimal,
            .destination_stage = .{},
            .destination_access = .{},
            .destination_layout = .present_src_khr,
        });
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

    var vertex_positions_staging_buffer = try graphics.Buffer.initData([3]f32, vertex_positions, .staging);
    errdefer vertex_positions_staging_buffer.deinit();

    try self.vertex_position_staging_buffers.append(self.allocator, vertex_positions_staging_buffer);

    // try self.vertex_position_buffer.update([3]f32, self.vertex_position_offset * @sizeOf([3]f32), vertex_positions);
    self.vertex_position_offset += vertex_positions.len;

    var vertex_staging_buffer = try graphics.Buffer.initData(Vertex, vertices, .staging);
    errdefer vertex_staging_buffer.deinit();

    // try self.vertex_buffer.update(Vertex, self.vertex_offset * @sizeOf(Vertex), vertices);
    try self.vertex_staging_buffers.append(self.allocator, vertex_staging_buffer);
    self.vertex_offset += vertices.len;

    var index_staging_buffer = try graphics.Buffer.initData(u32, indices, .staging);
    errdefer index_staging_buffer.deinit();

    // try self.index_buffer.update(u32, self.index_offset * @sizeOf(u32), indices);
    try self.index_staging_buffers.append(self.allocator, index_staging_buffer);
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

    var albedo_image = try Image.init(
        albedo_texture_width, 
        albedo_texture_height, 
        1, 
        1,
        .r8g8b8a8_srgb, 
        .shader_read_only_optimal,
        .{
            .transfer_dst_bit = true, 
            .sampled_bit = true, 
        }
    );
    errdefer albedo_image.deinit();

    try self.albedo_images.append(self.allocator, albedo_image);

    var albedo_staging_buffer = try graphics.Buffer.initData(u8, albedo_texture_data, .staging); 
    errdefer albedo_staging_buffer.deinit();

    var albedo_transfer_event = try graphics.Event.init();
    errdefer albedo_transfer_event.deinit();

    try self.image_transfer_events.append(self.allocator, albedo_transfer_event);
    try self.image_staging_buffers.append(self.allocator, albedo_staging_buffer);

    var albedo_sampler = try Sampler.init(.nearest, .nearest, null);
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
    //Should really check if the transfer command buffer is pending
    if (self.image_staging_fence.getStatus() == false)
    {
        const material_data = self.materials.items[@enumToInt(material)];
        const event: graphics.Event = self.image_transfer_events.items[material_data.albedo_texture_index];

        //If the texture is still being transfered by the transfer hardware, don't draw
        if (event.getStatus() == false)
        {
            return;
        }
    }

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