const CommandBuffer = @This();

const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");
const GraphicsPipeline = @import("GraphicsPipeline.zig");
const Buffer = @import("Buffer.zig");
const Image = @import("Image.zig");

pub const Queue = enum 
{
    graphics,
    compute,
};

handle: vk.CommandBuffer,
queue: Queue,
pipeline_layout: vk.PipelineLayout,
wait_fence: vk.Fence, 

pub fn init(queue: Queue) !CommandBuffer
{
    var self: CommandBuffer = .{
        .handle = .null_handle,
        .queue = queue,
        .pipeline_layout = .null_handle,
        .wait_fence = .null_handle,
    };

    const pool = switch (self.queue)
    {
        .graphics => Context.self.graphics_command_pool,
        .compute => Context.self.compute_command_pool,  
    };

    self.wait_fence = try Context.self.vkd.createFence(Context.self.device, &.{ .flags = .{ .signaled_bit = false, } }, &Context.self.allocation_callbacks);
    errdefer Context.self.vkd.destroyFence(Context.self.device, self.wait_fence, &Context.self.allocation_callbacks);

    try Context.self.vkd.allocateCommandBuffers(Context.self.device, &.{
        .command_pool = pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, @ptrCast([*]vk.CommandBuffer, &self.handle));

    return self;
}

pub fn deinit(self: *CommandBuffer) void
{
    defer self.* = undefined;

    const pool = switch (self.queue)
    {
        .graphics => Context.self.graphics_command_pool,
        .compute => Context.self.compute_command_pool,  
    };

    defer Context.self.vkd.destroyFence(Context.self.device, self.wait_fence, &Context.self.allocation_callbacks);
    defer Context.self.vkd.freeCommandBuffers(Context.self.device, pool, 1, @ptrCast([*]vk.CommandBuffer, &self.handle));
}

pub fn begin(self: CommandBuffer) !void 
{
    try Context.self.vkd.resetCommandBuffer(self.handle, .{});
    try Context.self.vkd.beginCommandBuffer(self.handle, &.{
        .flags = .{
            .one_time_submit_bit = true,
        },
        .p_inheritance_info = null,
    });
}

pub fn end(self: CommandBuffer) void 
{
    Context.self.vkd.endCommandBuffer(self.handle) catch unreachable;
}

pub fn submitAndWait(self: CommandBuffer) !void 
{
    try Context.self.vkd.queueSubmit2(Context.self.graphics_queue, 1, &[_]vk.SubmitInfo2
    {
        .{
            .flags = .{},
            .wait_semaphore_info_count = 0,
            .p_wait_semaphore_infos = undefined,
            .command_buffer_info_count = 1,
            .p_command_buffer_infos = &[_]vk.CommandBufferSubmitInfo {
                .{
                    .command_buffer = self.handle,
                    .device_mask = 0,
                }
            },
            .signal_semaphore_info_count = 0,
            .p_signal_semaphore_infos = undefined,
        }
    }, self.wait_fence);

    _ = try Context.self.vkd.waitForFences(Context.self.device, 1, @ptrCast([*]const vk.Fence, &self.wait_fence), vk.TRUE, std.math.maxInt(u64));
    try Context.self.vkd.resetFences(Context.self.device, 1, @ptrCast([*]const vk.Fence, &self.wait_fence));
}

pub fn beginRenderPass(self: CommandBuffer) void 
{
    _ = self;
}

pub fn endRenderPass(self: CommandBuffer) void 
{
    _ = self;
}

pub fn setGraphicsPipeline(self: *CommandBuffer, pipeline: GraphicsPipeline) void 
{
    Context.self.vkd.cmdBindPipeline(
        self.handle, 
        .graphics, 
        pipeline.handle
    );

    self.pipeline_layout = pipeline.layout;
}

pub fn setVertexBuffer(self: CommandBuffer, buffer: Buffer) void 
{
    Context.self.vkd.cmdBindVertexBuffers(self.handle, 0, 1, @ptrCast([*]const vk.Buffer, &buffer.handle), @ptrCast([*]const u64, &@as(u64, 0)));
}

pub fn setPushData(self: CommandBuffer, comptime T: type, data: T) void 
{
    Context.self.vkd.cmdPushConstants(
        self.handle, 
        self.pipeline_layout, 
        .{ .vertex_bit = true, .fragment_bit = true }, 
        0, 
        @sizeOf(T), 
        &data
    );
}

pub const IndexType = enum 
{
    u16,
    u32,
};

pub fn setIndexBuffer(self: CommandBuffer, buffer: Buffer, index_type: IndexType) void
{
    Context.self.vkd.cmdBindIndexBuffer(self.handle, buffer.handle, 0, switch (index_type)
    {
        .u16 => .uint16,
        .u32 => .uint32,
    });
}

pub fn copyBuffer(self: CommandBuffer, source: Buffer, source_offset: usize, destination: Buffer, destination_offset: usize) void 
{
    const copy_region = vk.BufferCopy 
    {
        .src_offset = source_offset,
        .dst_offset = destination_offset,
        .size = @min(source.size, destination.size),
    };

    Context.self.vkd.cmdCopyBuffer(self.handle, source.handle, destination.handle, 1, @ptrCast([*]const vk.BufferCopy, &copy_region));
}

pub fn copyBufferToImage(self: CommandBuffer, source: Buffer, destination: Image) void
{
    std.log.debug("width = {}", .{ destination.width });
    std.log.debug("height = {}", .{ destination.height });
    std.log.debug("depth = {}", .{ destination.depth });

    Context.self.vkd.cmdCopyBufferToImage2(self.handle, &.{
        .src_buffer = source.handle,
        .dst_image = destination.handle,
        .dst_image_layout = .transfer_dst_optimal,
        .region_count = 1,
        .p_regions = &[_]vk.BufferImageCopy2
        {
            .{
                .buffer_offset = 0,
                .buffer_row_length = destination.width,
                .buffer_image_height = destination.height,
                .image_subresource = .{
                    .aspect_mask = .{
                        .color_bit = true,
                    },
                    .mip_level = 0,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
                .image_offset = .{ .x = 0, .y = 0, .z = 0, },
                .image_extent = .{ .width = destination.width, .height = destination.height, .depth = destination.depth },
            }
        },
    });
}

pub fn draw(
    self: CommandBuffer,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
) void 
{
    Context.self.vkd.cmdDraw(self.handle, vertex_count, instance_count, first_vertex, first_instance);
}

pub fn drawIndexed(
    self: CommandBuffer,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    vertex_offset: i32,
    first_instance: u32,
) void 
{
    Context.self.vkd.cmdDrawIndexed(
        self.handle,
        index_count,
        instance_count,
        first_index,
        vertex_offset,
        first_instance,
    );
}

pub const DrawIndexedIndirectCommand = extern struct
{
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    vertex_offset: i32,
    first_instance: u32, 
};

pub fn drawIndexedIndirect(
    self: CommandBuffer,
    draw_buffer: Buffer,
    draw_buffer_offset: usize,
    draw_count: usize,
) void 
{
    Context.self.vkd.cmdDrawIndexedIndirect(
        self.handle, 
        draw_buffer.handle, 
        draw_buffer_offset,
        @truncate(u32, draw_count),
        @sizeOf(DrawIndexedIndirectCommand),
    );
}

pub fn drawIndexedIndirectCount(
    self: CommandBuffer,
    draw_buffer: Buffer,
    draw_buffer_offset: usize,
    count_buffer: Buffer,
    count_buffer_offset: usize,
    max_draw_count: usize,
) void 
{
    Context.self.vkd.cmdDrawIndexedIndirectCount(
        self.handle, 
        draw_buffer.handle, 
        draw_buffer_offset, 
        count_buffer.handle, 
        count_buffer_offset, 
        @truncate(u32, max_draw_count),
        @sizeOf(DrawIndexedIndirectCommand),
    );
}