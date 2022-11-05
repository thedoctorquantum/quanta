const CommandBuffer = @This();

const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");
const GraphicsPipeline = @import("GraphicsPipeline.zig");

pub const Queue = enum 
{
    graphics,
    compute,
};

handle: vk.CommandBuffer,
queue: Queue,

pub fn init(queue: Queue) !CommandBuffer
{
    var self: CommandBuffer = .{
        .handle = .null_handle,
        .queue = queue
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

pub fn setGraphicsPipeline(self: CommandBuffer, pipeline: GraphicsPipeline) void 
{
    Context.self.vkd.cmdBindPipeline(
        self.handle, 
        .graphics, 
        pipeline.handle
    );
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