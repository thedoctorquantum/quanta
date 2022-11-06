const CommandBuffer = @This();

const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");
const GraphicsPipeline = @import("GraphicsPipeline.zig");
const Buffer = @import("Buffer.zig");

pub const Queue = enum 
{
    graphics,
    compute,
};

handle: vk.CommandBuffer,
queue: Queue,
pipeline_layout: vk.PipelineLayout,

pub fn init(queue: Queue) !CommandBuffer
{
    var self: CommandBuffer = .{
        .handle = .null_handle,
        .queue = queue,
        .pipeline_layout = .null_handle,
    };

    const pool = switch (self.queue)
    {
        .graphics => Context.self.graphics_command_pool,
        .compute => Context.self.compute_command_pool,  
    };

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

pub fn copyBuffer(self: CommandBuffer, source: Buffer, destination: Buffer) void 
{
    const copy_region = vk.BufferCopy 
    {
        .src_offset = 0,
        .dst_offset = 0,
        .size = @min(source.size, destination.size),
    };

    Context.self.vkd.cmdCopyBuffer(self.handle, source.handle, destination.handle, 1, @ptrCast([*]const vk.BufferCopy, &copy_region));
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