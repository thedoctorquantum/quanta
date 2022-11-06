const std = @import("std");
const builtin = @import("builtin");
const quanta = @import("quanta");
const windowing = quanta.windowing;
const window = quanta.windowing.window;
const GraphicsContext = quanta.graphics.Context;
const Swapchain = quanta.graphics.Swapchain;
const CommandBuffer = quanta.graphics.CommandBuffer;
const GraphicsPipeline = quanta.graphics.GraphicsPipeline;
const Buffer = quanta.graphics.Buffer;
const vk = quanta.graphics.vulkan;

const shaders = @import("shaders.zig");

pub fn main() !void 
{
    std.log.debug("All your {s} are belong to us.", .{ "codebase" });
    std.log.debug("{s}", .{ "debug" });
    std.log.warn("{s}", .{ "warn" });
    std.log.err("{s}", .{ "err" });

    var gpa = if (builtin.mode == .Debug)
        std.heap.GeneralPurposeAllocator(.{}) {}
    else {};
    defer if (builtin.mode == .Debug) std.debug.assert(!gpa.deinit());

    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

    try window.init(640, 480, "Quanta Example");
    defer window.deinit();

    // var graphics_context: GraphicsContext = undefined;

    try GraphicsContext.init(allocator);
    defer GraphicsContext.deinit();

    var swapchain = try Swapchain.init(allocator, .{ .width = 640, .height = 480 });
    defer swapchain.deinit();

    const cmdbufs = try allocator.alloc(CommandBuffer, swapchain.swap_images.len);
    defer allocator.free(cmdbufs);

    for (cmdbufs) |*cmdbuf|
    {
        cmdbuf.* = try CommandBuffer.init(.graphics);
    }

    defer for (cmdbufs) |*cmdbuf|
    {
        cmdbuf.deinit();
    };

    var pipeline = try GraphicsPipeline.init(
        .{
            .color_attachment_formats = &[_]vk.Format 
            {
                swapchain.surface_format.format,
            },
            .vertex_shader_binary = shaders.tri_vert_spv,
            .fragment_shader_binary = shaders.tri_frag_spv,
        },
        shaders.TriVertexInput,
    );
    defer pipeline.deinit();

    var vertex_buffer = try Buffer.initData(
        shaders.TriVertexInput, 
        &[_]shaders.TriVertexInput
        {
            .{  
                .in_position = .{ 1, 1, 0 },
                .in_color = .{ 1, 0, 0 },
            },
            .{  
                .in_position = .{ -1, 1, 0 },
                .in_color = .{ 0, 1, 0 },
            },
            .{  
                .in_position = .{ 0, -1, 0 },
                .in_color = .{ 0, 0, 1 },
            },
        },
        .vertex
    );
    defer vertex_buffer.deinit(); 

    var index_buffer = try Buffer.initData(u16, &.{ 0, 1, 2 }, .index);
    defer index_buffer.deinit();

    const time_start = std.time.milliTimestamp();

    const in_flight_fence = try GraphicsContext.self.vkd.createFence(GraphicsContext.self.device, &.{ .flags = .{ .signaled_bit = false } }, &GraphicsContext.self.allocation_callbacks);
    defer GraphicsContext.self.vkd.destroyFence(GraphicsContext.self.device, in_flight_fence, &GraphicsContext.self.allocation_callbacks);

    const target_frame_time: i64 = 16; 

    var delta_time: i64 = 0;

    while (!window.shouldClose())
    {
        const time_begin = std.time.milliTimestamp();

        defer {
            delta_time = std.time.milliTimestamp() - time_begin;
            
            if (delta_time < target_frame_time)
            {
                //Slow down the game loop
                std.time.sleep(@intCast(u64, ((target_frame_time - delta_time) * std.time.ns_per_ms)));
            }
        }

        const image_index = swapchain.image_index;
        const cmdbuf: CommandBuffer = cmdbufs[image_index];
        const image = swapchain.swap_images[image_index];

        //record commands
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

            try cmdbuf.begin();
            defer cmdbuf.end();

            GraphicsContext.self.vkd.cmdPipelineBarrier2(
                cmdbuf.handle, 
                &.{
                    .dependency_flags = .{ .by_region_bit = true, },
                    .memory_barrier_count = 0,
                    .p_memory_barriers = undefined,
                    .buffer_memory_barrier_count = 0,
                    .p_buffer_memory_barriers = undefined,
                    .image_memory_barrier_count = 1,
                    .p_image_memory_barriers = @ptrCast([*]const vk.ImageMemoryBarrier2, &vk.ImageMemoryBarrier2
                    {
                        .src_stage_mask = .{
                            .top_of_pipe_bit = true,
                        },
                        .dst_stage_mask = .{
                            .color_attachment_output_bit = true,
                        },
                        .src_access_mask = .{},
                        .dst_access_mask = .{ .color_attachment_write_bit = true },
                        .old_layout = .@"undefined",
                        .new_layout = .color_attachment_optimal,
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
            
            //Render pass #1
            {
                const time = @intToFloat(f32, std.time.milliTimestamp() - time_start);

                const color_attachment = vk.RenderingAttachmentInfo
                {
                    .image_view = image.view,
                    .image_layout = .color_attachment_optimal,
                    .resolve_mode = .{},
                    .resolve_image_view = .null_handle,
                    .resolve_image_layout = .@"undefined",
                    .load_op = .clear,
                    .store_op = .store,
                    .clear_value = .{ 
                        .color = .{ 
                            .float_32 = .{ 0, std.math.fabs(std.math.sin(time * 0.001)), 0, 1 },
                        },
                    },
                };

                GraphicsContext.self.vkd.cmdBeginRendering(cmdbuf.handle, &.{
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
                defer GraphicsContext.self.vkd.cmdEndRendering(cmdbuf.handle);

                GraphicsContext.self.vkd.cmdSetViewport(cmdbuf.handle, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));
                GraphicsContext.self.vkd.cmdSetScissor(cmdbuf.handle, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor));

                cmdbuf.setGraphicsPipeline(pipeline);
                cmdbuf.setVertexBuffer(vertex_buffer);
                cmdbuf.setIndexBuffer(index_buffer, .u32);

                cmdbuf.draw(3, 1, 0, 0);
            }
            
            GraphicsContext.self.vkd.cmdPipelineBarrier2(
                cmdbuf.handle, 
                &.{
                    .dependency_flags = .{ .by_region_bit = true, },
                    .memory_barrier_count = 0,
                    .p_memory_barriers = undefined,
                    .buffer_memory_barrier_count = 0,
                    .p_buffer_memory_barriers = undefined,
                    .image_memory_barrier_count = 1,
                    .p_image_memory_barriers = @ptrCast([*]const vk.ImageMemoryBarrier2, &vk.ImageMemoryBarrier2
                    {
                        .src_stage_mask = .{
                            .color_attachment_output_bit = true,
                        },
                        .dst_stage_mask = .{
                            .bottom_of_pipe_bit = true,
                        },
                        .src_access_mask = .{ .color_attachment_write_bit = true },
                        .dst_access_mask = .{},
                        .old_layout = .color_attachment_optimal,
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
                        .command_buffer = cmdbuf.handle,
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
        }, in_flight_fence);

        _ = try GraphicsContext.self.vkd.queuePresentKHR(GraphicsContext.self.graphics_queue, &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]const vk.Semaphore, &image.render_finished),
            .swapchain_count = 1,
            .p_swapchains = @ptrCast([*]const vk.SwapchainKHR, &swapchain.handle),
            .p_image_indices = @ptrCast([*]const u32, &image_index),
            .p_results = null,
        });

        const result = try GraphicsContext.self.vkd.acquireNextImageKHR(
            GraphicsContext.self.device,
            swapchain.handle,
            std.math.maxInt(u64),
            swapchain.next_image_acquired,
            .null_handle,
        );

        std.mem.swap(vk.Semaphore, &swapchain.swap_images[result.image_index].image_acquired, &swapchain.next_image_acquired);
        swapchain.image_index = result.image_index;

        _ = try GraphicsContext.self.vkd.waitForFences(GraphicsContext.self.device, 1, @ptrCast([*]const vk.Fence, &in_flight_fence), vk.TRUE, std.math.maxInt(u64));
        try GraphicsContext.self.vkd.resetFences(GraphicsContext.self.device, 1, @ptrCast([*]const vk.Fence, &in_flight_fence));
    }

    try GraphicsContext.self.vkd.deviceWaitIdle(GraphicsContext.self.device);
}

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void 
{
    const terminal_red = "\x1B[31m";
    const terminal_yellow = "\x1B[33m";
    const terminal_blue = "\x1B[34m";
    const terminal_green = "\x1B[32m";

    const color_begin = switch (message_level)
    {
        .err => terminal_red,
        .warn => terminal_yellow,
        .info => terminal_blue,
        .debug => terminal_green,
    };

    const color_end = "\x1B[0;39m";

    const level_txt = "[" ++ color_begin ++ comptime message_level.asText() ++ color_end ++ "]";
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const stderr = std.io.getStdErr().writer();
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    nosuspend stderr.print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;
}