const std = @import("std");
const quanta = @import("quanta");
const builtin = @import("builtin");
const windowing = quanta.windowing;
const window = quanta.windowing.window;
const GraphicsContext = quanta.graphics.Context;
const Swapchain = quanta.graphics.Swapchain;
const vk = quanta.graphics.vulkan;

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

    try window.init(640, 480, "example");
    defer window.deinit();

    var graphics_context: GraphicsContext = undefined;

    try graphics_context.init(allocator);
    defer graphics_context.deinit();

    var swapchain = try Swapchain.init(&graphics_context, allocator, .{ .width = 640, .height = 480 });
    defer swapchain.deinit();

    const cmdbufs = try allocator.alloc(vk.CommandBuffer, swapchain.swap_images.len);
    defer allocator.free(cmdbufs);

    const present_command_bufs = try allocator.alloc(vk.CommandBuffer, swapchain.swap_images.len);
    defer allocator.free(present_command_bufs);

    try graphics_context.vkd.allocateCommandBuffers(graphics_context.device, &.{
        .command_pool = graphics_context.graphics_command_pool,
        .level = .primary,
        .command_buffer_count = @truncate(u32, cmdbufs.len),
    }, cmdbufs.ptr);
    defer graphics_context.vkd.freeCommandBuffers(graphics_context.device, graphics_context.graphics_command_pool, @truncate(u32, cmdbufs.len), cmdbufs.ptr);

    const time_start = std.time.milliTimestamp();

    const in_flight_fence = try graphics_context.vkd.createFence(graphics_context.device, &.{ .flags = .{ .signaled_bit = false } }, &graphics_context.allocation_callbacks);
    defer graphics_context.vkd.destroyFence(graphics_context.device, in_flight_fence, &graphics_context.allocation_callbacks);

    while (!window.shouldClose())
    {
        const image_index = swapchain.image_index;
        const cmdbuf = cmdbufs[image_index];
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

            const scissor = vk.Rect2D{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{ .width = 640, .height = 480 },
            };

            try graphics_context.vkd.resetCommandBuffer(cmdbuf, .{});
            try graphics_context.vkd.beginCommandBuffer(cmdbuf, &.{
                .flags = .{
                    .one_time_submit_bit = true,
                },
                .p_inheritance_info = null,
            });

            graphics_context.vkd.cmdPipelineBarrier2(
                cmdbuf, 
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

                graphics_context.vkd.cmdBeginRendering(cmdbuf, &.{
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
                defer graphics_context.vkd.cmdEndRendering(cmdbuf);

                graphics_context.vkd.cmdSetViewport(cmdbuf, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));
                graphics_context.vkd.cmdSetScissor(cmdbuf, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor));
            }
            
            graphics_context.vkd.cmdPipelineBarrier2(
                cmdbuf, 
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

            try graphics_context.vkd.endCommandBuffer(cmdbuf);
        }

        try graphics_context.vkd.queueSubmit2(graphics_context.graphics_queue, 1, &[_]vk.SubmitInfo2
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
                        .command_buffer = cmdbuf,
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

        _ = try graphics_context.vkd.queuePresentKHR(graphics_context.graphics_queue, &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]const vk.Semaphore, &image.render_finished),
            .swapchain_count = 1,
            .p_swapchains = @ptrCast([*]const vk.SwapchainKHR, &swapchain.handle),
            .p_image_indices = @ptrCast([*]const u32, &image_index),
            .p_results = null,
        });

        const result = try swapchain.context.vkd.acquireNextImageKHR(
            swapchain.context.device,
            swapchain.handle,
            std.math.maxInt(u64),
            swapchain.next_image_acquired,
            .null_handle,
        );

        std.mem.swap(vk.Semaphore, &swapchain.swap_images[result.image_index].image_acquired, &swapchain.next_image_acquired);
        swapchain.image_index = result.image_index;

        _ = try graphics_context.vkd.waitForFences(graphics_context.device, 1, @ptrCast([*]const vk.Fence, &in_flight_fence), vk.TRUE, std.math.maxInt(u64));
        try swapchain.context.vkd.resetFences(swapchain.context.device, 1, @ptrCast([*]const vk.Fence, &in_flight_fence));
    }

    try graphics_context.vkd.deviceWaitIdle(graphics_context.device);
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