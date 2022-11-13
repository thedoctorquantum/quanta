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

///Returns true if the fence is signaled, otherwise it returns false
pub fn getStatus(self: Fence) bool 
{
    const status = Context.self.vkd.getFenceStatus(Context.self.device, self.handle) catch unreachable;

    return if (status == .success) true else false;
}

pub fn reset(self: Fence) void 
{
    Context.self.vkd.resetFences(Context.self.device, 1, @ptrCast([*]const vk.Fence, &self.handle)) catch unreachable;
}