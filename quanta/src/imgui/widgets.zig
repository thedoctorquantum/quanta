const std = @import("std");
const imgui = @import("cimgui.zig");

pub fn begin(title: [:0]const u8) bool
{
    return imgui.igBegin(title.ptr, null, 0);
}

pub fn end() void 
{
    imgui.igEnd();
}

pub fn text(string: []const u8) void 
{
    imgui.igTextUnformatted(string.ptr, string.ptr + string.len);
}

pub fn textFormat(comptime format: []const u8, args: anytype) void 
{
    var format_buf: [4096 * 8]u8 = undefined;

    text(std.fmt.bufPrint(&format_buf, format, args) catch unreachable);
}