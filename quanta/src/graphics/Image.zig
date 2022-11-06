const Image = @This();

const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const Buffer = @import("Buffer.zig");

handle: vk.Image,
view: vk.ImageView,
memory: vk.DeviceMemory,
size: usize,
format: vk.Format,
layout: vk.ImageLayout,
width: u32,
height: u32,
depth: u32,

pub fn initData(
    data: []const u8,
    width: u32,
    height: u32,
    depth: u32,
    format: vk.Format,
    layout: vk.ImageLayout,
) !Image
{
    var image = try init(width, height, depth, format, layout);
    errdefer image.deinit();

    var source_buffer = try Buffer.init(image.size, .staging);
    defer source_buffer.deinit();

    {
        const mapped = try source_buffer.map(u8);
        defer source_buffer.unmap();

        std.mem.copy(u8, mapped, data);
    }

    var command_buffer = try CommandBuffer.init(.graphics);
    defer command_buffer.deinit();

    {
        try command_buffer.begin();

        command_buffer.copyBufferToImage(source_buffer, image);

        Context.self.vkd.cmdPipelineBarrier2(
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
                    .src_stage_mask = .{
                        .top_of_pipe_bit = true,
                    },
                    .dst_stage_mask = .{
                        .copy_bit = true,
                    },
                    .src_access_mask = .{},
                    .dst_access_mask = .{ .transfer_write_bit = true, },
                    .old_layout = .transfer_dst_optimal,
                    .new_layout = image.layout,
                    .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .image = image.handle,
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

        command_buffer.end();

        try command_buffer.submitAndWait();
    }

    return image;
}

pub fn init(
    width: u32,
    height: u32,
    depth: u32,
    format: vk.Format,
    layout: vk.ImageLayout,
) !Image 
{
    var self = Image
    {
        .handle = .null_handle,
        .view = .null_handle,
        .memory = .null_handle,
        .format = format,
        .layout = layout,
        .width = width,
        .height = height,
        .depth = depth,
        .size = 0,
    };

    self.handle = try Context.self.vkd.createImage(
        Context.self.device, 
        &.{
            .flags = .{ .@"alias_bit" = true, },
            .image_type = .@"2d",
            .format = format,
            .extent = .{ .width = width, .height = height, .depth = depth },
            .mip_levels = 1,
            .array_layers = 1,
            .samples = .{ .@"1_bit" = true, },
            .tiling = .optimal,
            .usage = .{ .transfer_dst_bit = true, .sampled_bit = true, },
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
            .initial_layout = .@"undefined",
        }, 
        &Context.self.allocation_callbacks
    );
    errdefer Context.self.vkd.destroyImage(Context.self.device, self.handle, &Context.self.allocation_callbacks);

    const memory_requirements = Context.self.vkd.getImageMemoryRequirements(Context.self.device, self.handle);

    self.size = memory_requirements.size;

    self.memory = try Context.deviceAllocate(memory_requirements, .{ .device_local_bit = true });
    errdefer Context.self.vkd.freeMemory(Context.self.device, self.memory, &Context.self.allocation_callbacks);

    try Context.self.vkd.bindImageMemory(Context.self.device, self.handle, self.memory, 0);
    
    self.view = try Context.self.vkd.createImageView(
        Context.self.device, 
        &.{
            .flags = .{},
            .image = self.handle,
            .view_type = .@"2d",
            .format = self.format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        }, 
        &Context.self.allocation_callbacks
    );
    errdefer Context.self.vkd.destroyImageView(Context.self.device, self.view, &Context.self.allocation_callbacks);

    var command_buffer = try CommandBuffer.init(.graphics);
    defer command_buffer.deinit();

    {
        try command_buffer.begin();

        Context.self.vkd.cmdPipelineBarrier2(
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
                    .src_stage_mask = .{
                        .top_of_pipe_bit = true,
                    },
                    .dst_stage_mask = .{
                        .copy_bit = true,
                    },
                    .src_access_mask = .{},
                    .dst_access_mask = .{ .transfer_write_bit = true, },
                    .old_layout = .@"undefined",
                    .new_layout = .transfer_dst_optimal,
                    .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .image = self.handle,
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

        command_buffer.end();
        try command_buffer.submitAndWait();
    }

    return self;
}

pub fn deinit(self: *Image) void 
{
    defer self.* = undefined;

    defer Context.self.vkd.destroyImage(Context.self.device, self.handle, &Context.self.allocation_callbacks);
    defer Context.self.vkd.destroyImageView(Context.self.device, self.view, &Context.self.allocation_callbacks);
    defer Context.self.vkd.freeMemory(Context.self.device, self.memory, &Context.self.allocation_callbacks);
}