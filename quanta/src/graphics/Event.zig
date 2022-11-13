const Event = @This();

const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");

handle: vk.Event,

pub fn init() !Event 
{
    var self = Event
    {
        .handle = .null_handle,
    };

    self.handle = try Context.self.vkd.createEvent(Context.self.device, &.{ .flags = .{} }, &Context.self.allocation_callbacks);

    return self;
}

pub fn deinit(self: *Event) void 
{
    defer self.* = undefined;

    defer Context.self.vkd.destroyEvent(Context.self.device, self.handle, &Context.self.allocation_callbacks);
}

///Returns true if the event is signaled, otherwise it returns false
pub fn getStatus(self: Event) bool 
{
    const status = Context.self.vkd.getEventStatus(Context.self.device, self.handle) catch unreachable;

    return if (status == .success) true else false;
}

pub fn reset(self: Event) void 
{
    Context.self.vkd.resetEvent(Context.self.device, self.handle);
}