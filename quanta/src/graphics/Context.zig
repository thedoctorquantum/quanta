const Context = @This();
const vk = @import("vk.zig");

pub fn init() !Context 
{
    var self = Context {};

    return self;
}

pub fn deinit(self: *Context) void 
{
    self.* = undefined;
}