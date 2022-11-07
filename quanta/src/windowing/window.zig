const std = @import("std");
const glfw = @import("glfw");

pub var window: glfw.Window = undefined;

var self: @This() = undefined;

width: u32,
height: u32,

pub fn init(width: u32, height: u32, title: [:0]const u8) !void 
{
    try glfw.init(.{});

    self.width = width;
    self.height = height;

    window = try glfw.Window.create(width, height, title.ptr, null, null, .{ 
        .client_api = .no_api,
        .resizable = false,
    });
}

pub fn deinit() void 
{
    window.destroy();
    glfw.terminate();
}

pub fn shouldClose() bool 
{
    glfw.pollEvents() catch unreachable;

    return window.shouldClose();
}

pub fn getWidth() u32
{
    return self.width;
}

pub fn getHeight() u32
{
    return self.height;
}