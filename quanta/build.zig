const std = @import("std");
const glfw = @import("../lib/mach-glfw/build.zig");

pub fn build() void 
{

}

pub fn link(exe: *std.build.LibExeObjStep) !void 
{
    exe.addPackage(glfw.pkg);

    var package = std.build.Pkg 
    {
        .name = "quanta",
        .source = .{ .path = "quanta/src/main.zig" },
        .dependencies = &.{},
    };

    exe.addPackage(package);

    try glfw.link(exe.builder, exe, .{});
}