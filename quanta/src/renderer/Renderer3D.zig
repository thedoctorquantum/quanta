const Renderer3D = @This();

const std = @import("std");
const graphics = @import("../graphics.zig");
const GraphicsContext = graphics.Context;
const vk = graphics.vulkan;

const tri_vert_spv = @alignCast(4, @embedFile("spirv/tri.vert.spv"));
const tri_frag_spv = @alignCast(4, @embedFile("spirv/tri.frag.spv"));

const ColorPassPushConstants = extern struct 
{
    position: [3]f32,
};

pub var self: Renderer3D = undefined;

allocator: std.mem.Allocator,
swapchain: *graphics.Swapchain,
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
next_mesh: u32,

pub fn init(
    allocator: std.mem.Allocator,
    swapchain: *graphics.Swapchain
) !void 
{
    self.allocator = allocator;
    self.swapchain = swapchain;
    self.draw_index = 0;
    self.next_mesh = 0;
    self.vertex_offset = 0;
    self.index_offset = 0;
    self.command_buffers = try allocator.alloc(graphics.CommandBuffer, swapchain.swap_images.len);
    errdefer allocator.free(self.command_buffers);

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
        .{
            .color_attachment_formats = &[_]vk.Format 
            {
                swapchain.surface_format.format,
            },
            .vertex_shader_binary = tri_vert_spv,
            .fragment_shader_binary = tri_frag_spv,
        },
        null,
        ColorPassPushConstants,
        null,
    );
    errdefer self.color_pipeline.deinit();

    GraphicsContext.self.vkd.updateDescriptorSets(
        GraphicsContext.self.device, 
        1, 
        &[_]vk.WriteDescriptorSet
        {
            .{
                .dst_set = self.color_pipeline.descriptor_sets[0],
                .dst_binding = 0,
                .dst_array_element = 0,
                .descriptor_count = 1,
                .descriptor_type = .storage_buffer,
                .p_image_info = undefined,
                .p_buffer_info = &[_]vk.DescriptorBufferInfo
                {
                    .{
                        .buffer = self.vertex_buffer.handle,
                        .offset = 0,
                        .range = self.vertex_buffer.size,
                    }
                },
                .p_texel_buffer_view = undefined,
            },
            // .{
            //     .dst_set = self.color_pipeline.descriptor_sets[0],
            //     .dst_binding = 1,
            //     .dst_array_element = 0,
            //     .descriptor_count = 1,
            //     .descriptor_type = .combined_image_sampler,
            //     .p_image_info = &[_]vk.DescriptorImageInfo
            //     {
            //         .{
            //             .sampler = .null_handle,
            //             .image_view = .null_handle,
            //             .image_layout = undefined,
            //         },
            //     },
            //     .p_buffer_info = undefined,
            //     .p_texel_buffer_view = undefined,
            // },
        }, 
        0, 
        undefined,
    );
}

pub fn deinit() void 
{
    defer self = undefined;
    defer self.allocator.free(self.command_buffers);
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
}

pub fn beginRender() void 
{
    self.draw_index = 0;
}

pub fn endRender() !void
{
    const image_index = self.swapchain.image_index;
    const image = self.swapchain.swap_images[image_index];
    const command_buffer = &self.command_buffers[image_index];

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

        //Color pass #1
        {
            const viewport = vk.Viewport
            {
                .x = 0,
                .y = 0,
                .width = @intToFloat(f32, 640),
                .height = @intToFloat(f32, 480),
                .min_depth = 0,
                .max_depth = 1,
            };

            const scissor = vk.Rect2D
            {
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{ .width = 640, .height = 480 },
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

            GraphicsContext.self.vkd.cmdBeginRendering(command_buffer.handle, &.{
                .flags = .{},
                .render_area = .{ 
                    .offset = .{ .x = 0, .y = 0 }, 
                    .extent = .{ .width = 640, .height = 480 } 
                },
                .layer_count = 1,
                .view_mask = 0,
                .color_attachment_count = 1,
                .p_color_attachments = @ptrCast([*]const @TypeOf(color_attachment), &color_attachment),
                .p_depth_attachment = null,
                .p_stencil_attachment = null,
            });
            defer GraphicsContext.self.vkd.cmdEndRendering(command_buffer.handle);

            GraphicsContext.self.vkd.cmdSetViewport(command_buffer.handle, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));
            GraphicsContext.self.vkd.cmdSetScissor(command_buffer.handle, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor));

            command_buffer.setGraphicsPipeline(self.color_pipeline);
            command_buffer.setIndexBuffer(self.index_buffer, .u32);
            command_buffer.setPushData(ColorPassPushConstants, .{ .position = .{ 0, 0, 0 } });

            GraphicsContext.self.vkd.cmdBindDescriptorSets(
                command_buffer.handle, 
                .graphics,
                command_buffer.pipeline_layout, 
                0, 
                1, 
                self.color_pipeline.descriptor_sets.ptr, 
                0, 
                undefined
            );

            command_buffer.drawIndexedIndirect(
                self.draw_indirect_buffer, 
                0, 
                self.draws.len
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
}

pub const Mesh = extern struct 
{
    vertex_offset: u32,
    vertex_count: u32,
    index_offset: u32,
    index_count: u32,
};
pub const MeshHandle = enum(u32) { _ }; 

pub const Vertex = extern struct 
{
    position: [3]f32,
    normal: [3]f32,
    color: u32,
    uv: [2]f32,
};

pub fn createMesh(
    vertices: []const Vertex,
    indices: []const u32,
) !MeshHandle
{
    const mesh_handle = self.next_mesh;
    self.next_mesh += 1;

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

pub fn drawMesh(
    mesh: MeshHandle,
) void 
{
    const mesh_data: Mesh = self.meshes.items[@enumToInt(mesh)];

    self.draws[self.draw_index] = .{
        .first_index = mesh_data.index_offset / @sizeOf(u32),
        .index_count = mesh_data.index_count,
        .vertex_offset = @intCast(i32, mesh_data.vertex_offset),
        .first_instance = 0, 
        .instance_count = 1,
    };
    self.draw_index += 1;
}