const std = @import("std");
const quanta = @import("quanta");
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

    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer std.debug.assert(!gpa.deinit());

    const allocator = gpa.allocator();

    try window.init(640, 480, "example");
    defer window.deinit();

    var graphics_context: GraphicsContext = undefined;

    try graphics_context.init(allocator);
    defer graphics_context.deinit();

    var swapchain = try Swapchain.init(&graphics_context, allocator, .{ .width = 640, .height = 480 });
    defer swapchain.deinit();

    const cmdbufs = try allocator.alloc(vk.CommandBuffer, swapchain.swap_images.len);
    defer allocator.free(cmdbufs);

    try graphics_context.vkd.allocateCommandBuffers(graphics_context.device, &.{
        .command_pool = graphics_context.graphics_command_pool,
        .level = .primary,
        .command_buffer_count = @truncate(u32, cmdbufs.len),
    }, cmdbufs.ptr);
    defer graphics_context.vkd.freeCommandBuffers(graphics_context.device, graphics_context.graphics_command_pool, @truncate(u32, cmdbufs.len), cmdbufs.ptr);

    var frame_i: usize = 0;

    while (!window.shouldClose())
    {
        if (frame_i > 60) break;
        // frame_i += 1;

        const cmdbuf = cmdbufs[swapchain.image_index];

        std.log.debug("image_index: {}", .{ swapchain.image_index });

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
                .flags = .{},
                .p_inheritance_info = null,
            });

            std.log.debug("Barrier Transitioning form undefined->optimal", .{});

            // graphics_context.imageMemoryBarrier(
            //     cmdbuf, 
            //     swapchain.swap_images[swapchain.image_index].image, 
            //     .{
            //         .top_of_pipe_bit = true,
            //     },
            //     .{
            //         .color_attachment_output_bit = true,
            //     },
            //     .{}, 
            //     .{ .color_attachment_write_bit = true }, 
            //     .@"undefined", 
            //     .color_attachment_optimal
            // );

            graphics_context.vkd.cmdPipelineBarrier2(
                cmdbuf, 
                &.{
                    .dependency_flags = .{},
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
                        .image = swapchain.swap_images[swapchain.image_index].image,
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

            {
                const color_attachment = vk.RenderingAttachmentInfo
                {
                    .image_view = swapchain.swap_images[swapchain.image_index].view,
                    .image_layout = .color_attachment_optimal,
                    .resolve_mode = .{},
                    .resolve_image_view = .null_handle,
                    .resolve_image_layout = .@"undefined",
                    .load_op = .clear,
                    .store_op = .store,
                    .clear_value = .{ 
                        .color = .{ 
                            .float_32 = .{ 0, 1, 0, 1 },
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
            
            std.log.debug("Barrier Transitioning form optimal->present_src", .{});

            graphics_context.vkd.cmdPipelineBarrier2(
                cmdbuf, 
                &.{
                    .dependency_flags = .{},
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
                        .image = swapchain.swap_images[swapchain.image_index].image,
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

        const state = swapchain.present(cmdbuf) catch |err| switch (err) {
            error.OutOfDateKHR => Swapchain.PresentState.suboptimal,
            else => |narrow| return narrow,
        };

        _ = state;
    }

    try graphics_context.vkd.deviceWaitIdle(graphics_context.device);

    try swapchain.waitForAllFences();
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