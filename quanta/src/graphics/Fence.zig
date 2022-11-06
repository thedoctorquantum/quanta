const Fence = @This();

const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");

handle: vk.Fence,

pub fn init() !Fence 
{
    var self = Fence
    {
        .handle = .null_handle,
    };

    self.handle = try Context.self.vkd.createFence(Context.self.device, &.{ .flags = .{ .signaled_bit = false } }, &Context.self.allocation_callbacks);

    return self;
}

pub fn deinit(self: *Fence) void 
{
    defer self.* = undefined;

    defer Context.self.vkd.destroyFence(Context.self.device, self.handle, &Context.self.allocation_callbacks);
}

pub fn wait(self: Fence) void 
{
    _ = Context.self.vkd.waitForFences(Context.self.device, 1, @ptrCast([*]const vk.Fence, &self.handle), vk.TRUE, std.math.maxInt(u64)) catch unreachable;
}

pub fn reset(self: Fence) void 
{
    Context.self.vkd.resetFences(Context.self.device, 1, @ptrCast([*]const vk.Fence, &self.handle)) catch unreachable;
}