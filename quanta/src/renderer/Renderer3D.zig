const Renderer3D = @This();

const std = @import("std");
const window = @import("../windowing/window.zig");
const graphics = @import("../graphics.zig");
const GraphicsContext = graphics.Context;
const Image = graphics.Image;
const Sampler = graphics.Sampler;
const vk = graphics.vulkan;
const zalgebra = @import("zalgebra");

const tri_vert_spv = @alignCast(4, @embedFile("spirv/tri.vert.spv"));
const tri_frag_spv = @alignCast(4, @embedFile("spirv/tri.frag.spv"));

const ColorPassPushConstants = extern struct 
{
    view_projection: [4][4]f32,
};

pub var self: Renderer3D = undefined;

allocator: std.mem.Allocator,
swapchain: *graphics.Swapchain,
depth_image: graphics.Image,
command_buffers: []graphics.CommandBuffer, 
frame_fence: graphics.Fence,

vertex_buffer: graphics.Buffer,
vertex_offset: usize,
index_buffer: graphics.Buffer,
index_offset: usize,

color_pipeline: graphics.GraphicsPipeline,

draw_indirect_buffer: graphics.Buffer,
draws: []graphics.CommandBuffer.DrawIndexedIndirectCommand, 
draw_index: u32,

meshes: std.ArrayListUnmanaged(Mesh),

transforms: std.ArrayListUnmanaged([4][3]f32),
transforms_buffer: graphics.Buffer,

material_indices: std.ArrayListUnmanaged(u32),
material_indices_buffer: graphics.Buffer,

materials: std.ArrayListUnmanaged(Material),
materials_buffer: graphics.Buffer,

albedo_images: std.ArrayListUnmanaged(Image),
albedo_samplers: std.ArrayListUnmanaged(Sampler),

camera: Camera,

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

    self.depth_image = try Image.init(window.getWidth(), window.getHeight(), 1, vk.Format.d32_sfloat, vk.ImageLayout.attachment_optimal);
    errdefer self.depth_image.deinit();

    self.command_buffers = try allocator.alloc(graphics.CommandBuffer, swapchain.swap_images.len);
    errdefer allocator.free(self.command_buffers);

    self.transforms = .{};
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

    const command_count = 4096;

    self.draw_indirect_buffer = try graphics.Buffer.init(command_count * @sizeOf(graphics.CommandBuffer.DrawIndexedIndirectCommand), .indirect_draw);
    errdefer self.draw_indirect_buffer.deinit();

    self.draws = try self.draw_indirect_buffer.map(graphics.CommandBuffer.DrawIndexedIndirectCommand);

    const vertex_buffer_size = 128 * 1024 * 1024;

    self.vertex_buffer = try graphics.Buffer.init(vertex_buffer_size, .storage);
    errdefer self.vertex_buffer.deinit();

    self.index_buffer = try graphics.Buffer.init(vertex_buffer_size, .index);
    errdefer self.index_buffer.deinit();

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
        },
        null,
        ColorPassPushConstants,
        null,
    );
    errdefer self.color_pipeline.deinit();

    self.transforms_buffer = try graphics.Buffer.init(command_count * @sizeOf([4][3]f32), .storage);
    errdefer self.transforms_buffer.deinit();

    self.material_indices_buffer = try graphics.Buffer.init(command_count * @sizeOf(u32), .storage);
    errdefer self.material_indices_buffer.deinit();

    self.materials_buffer = try graphics.Buffer.init(command_count * @sizeOf(Material), .storage);
    errdefer self.materials_buffer.deinit();

    self.color_pipeline.setDescriptorBuffer(0, 0, self.vertex_buffer);
    self.color_pipeline.setDescriptorBuffer(1, 0, self.transforms_buffer);
    self.color_pipeline.setDescriptorBuffer(2, 0, self.material_indices_buffer);
    self.color_pipeline.setDescriptorBuffer(3, 0, self.materials_buffer);
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
    defer self.vertex_buffer.deinit();
    defer self.index_buffer.deinit();
    defer self.color_pipeline.deinit();
    defer self.meshes.deinit(self.allocator);
    defer self.transforms_buffer.deinit();
    defer self.material_indices_buffer.deinit();
    defer self.materials.deinit(self.allocator);
    defer self.materials_buffer.deinit();
    defer self.transforms.deinit(self.allocator);
    defer self.albedo_images.deinit(self.allocator);
    defer self.material_indices.deinit(self.allocator);
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

pub fn endRender() !void
{
    const image_index = self.swapchain.image_index;
    const image = self.swapchain.swap_images[image_index];
    const command_buffer = &self.command_buffers[image_index];

    try self.transforms_buffer.update([4][3]f32, 0, self.transforms.items);
    try self.material_indices_buffer.update(u32, 0, self.material_indices.items);
    try self.materials_buffer.update(Material, 0, self.materials.items);

    {
        command_buffer.begin() catch unreachable;
        defer command_buffer.end();

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

        //Color pass #1
        {
            const viewport = vk.Viewport
            {
                .x = 0,
                .y = 0,
                .width = @intToFloat(f32, window.getWidth()),
                .height = @intToFloat(f32, window.getHeight()),
                .min_depth = 0,
                .max_depth = 1,
            };

            const scissor = vk.Rect2D
            {
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{ .width = window.getWidth(), .height = window.getHeight() },
            };

            const color_attachment = vk.RenderingAttachmentInfo
            {
                .image_view = image.view,
                .image_layout = .attachment_optimal,
                .resolve_mode = .{},
                .resolve_image_view = .null_handle,
                .resolve_image_layout = .@"undefined",
                .load_op = .clear,
                .store_op = .store,
                .clear_value = .{ 
                    .color = .{ 
                        .float_32 = .{ 0, 0, 0, 1 },
                    },
                },
            };

            const depth_attachment = vk.RenderingAttachmentInfo
            {
                .image_view = self.depth_image.view,
                .image_layout = .attachment_optimal,
                .resolve_mode = .{},
                .resolve_image_view = .null_handle,
                .resolve_image_layout = .@"undefined",
                .load_op = .clear,
                .store_op = .dont_care,
                .clear_value = .{ 
                    .depth_stencil = .{ 
                        .depth = 1,
                        .stencil = 1,
                    },
                },
            };

            GraphicsContext.self.vkd.cmdBeginRendering(command_buffer.handle, &.{
                .flags = .{},
                .render_area = .{ 
                    .offset = .{ .x = 0, .y = 0 }, 
                    .extent = .{ .width = window.getWidth(), .height = window.getHeight() } 
                },
                .layer_count = 1,
                .view_mask = 0,
                .color_attachment_count = 1,
                .p_color_attachments = @ptrCast([*]const @TypeOf(color_attachment), &color_attachment),
                .p_depth_attachment = &depth_attachment,
                .p_stencil_attachment = null,
            });
            defer GraphicsContext.self.vkd.cmdEndRendering(command_buffer.handle);

            GraphicsContext.self.vkd.cmdSetViewport(command_buffer.handle, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));
            GraphicsContext.self.vkd.cmdSetScissor(command_buffer.handle, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor));

            const aspect_ratio: f32 = @intToFloat(f32, window.getWidth()) / @intToFloat(f32, window.getHeight());  
            const near_plane: f32 = 0.01;
            const far_plane: f32 = 1000;
            const fov: f32 = self.camera.fov;
            const projection = zalgebra.perspective(fov, aspect_ratio, near_plane, far_plane);
            const view_projection = projection.mul(
                zalgebra.lookAt(
                    .{ .data = self.camera.translation }, 
                    .{ .data = self.camera.target }, 
                    .{ .data = .{ 0, -1, 0 } }
                )
            );

            command_buffer.setGraphicsPipeline(self.color_pipeline);
            command_buffer.setIndexBuffer(self.index_buffer, .u32);
            command_buffer.setPushData(ColorPassPushConstants, .{
                .view_projection = view_projection.data,
            });

            command_buffer.drawIndexedIndirect(
                self.draw_indirect_buffer, 
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

    _ = try GraphicsContext.self.vkd.queuePresentKHR(GraphicsContext.self.graphics_queue, &.{
        .wait_semaphore_count = 1,
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

    self.transforms.clearRetainingCapacity();
    self.material_indices.clearRetainingCapacity();
}

const Mesh = extern struct 
{
    vertex_offset: u32,
    vertex_count: u32,
    index_offset: u32,
    index_count: u32,
};

pub const MeshHandle = enum(u32) { _ }; 

pub fn createMesh(
    vertices: []const Vertex,
    indices: []const u32,
) !MeshHandle
{
    const mesh_handle = @intCast(u32, self.meshes.items.len);

    try self.meshes.append(self.allocator, .{
        .vertex_offset = @intCast(u32, self.vertex_offset),
        .vertex_count = @intCast(u32, vertices.len),
        .index_offset = @intCast(u32, self.index_offset),
        .index_count = @intCast(u32, indices.len),
    });

    try self.vertex_buffer.update(Vertex, self.vertex_offset, vertices);
    self.vertex_offset += vertices.len * @sizeOf(Vertex);

    try self.index_buffer.update(u32, self.index_offset, indices);
    self.index_offset += indices.len * @sizeOf(u32);

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

    self.color_pipeline.setDescriptorImageSampler(4, material_handle, albedo_image, albedo_sampler);

    try self.materials.append(self.allocator, .{
        .albedo_texture_index = material_handle,
        .albedo_color = packUnorm4x8(albedo_color)
    });

    return @intToEnum(MaterialHandle, material_handle);
}

pub const Vertex = extern struct 
{
    position: [3]f32,
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
    const mesh_data: Mesh = self.meshes.items[@enumToInt(mesh)];

    self.draws[self.draw_index] = .{
        .first_index = mesh_data.index_offset / @sizeOf(u32),
        .index_count = mesh_data.index_count,
        .vertex_offset = @intCast(i32, mesh_data.vertex_offset / @sizeOf(Vertex)),
        .first_instance = self.draw_index, 
        .instance_count = 1,
    };

    self.transforms.append(
        self.allocator,
        [4][3]f32
        {
            transform.data[0][0..3].*,
            transform.data[1][0..3].*,
            transform.data[2][0..3].*,
            transform.data[3][0..3].*,
        }
    ) catch unreachable;

    self.material_indices.append(
        self.allocator, 
        @enumToInt(material)
    ) catch unreachable;

    self.draw_index += 1;
}