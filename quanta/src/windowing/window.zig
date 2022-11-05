const std = @import("std");
const glfw = @import("glfw");

pub var window: glfw.Window = undefined;

pub fn init(width: u32, height: u32, title: [:0]const u8) !void 
{
    try glfw.init(.{});

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