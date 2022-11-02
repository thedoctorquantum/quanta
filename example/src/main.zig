const std = @import("std");
const quanta = @import("quanta");
const windowing = quanta.windowing;
const window = quanta.windowing.window;

pub fn main() !void 
{
    std.log.debug("All your {s} are belong to us.", .{ "codebase" });
    std.log.debug("{s}", .{ "debug" });
    std.log.warn("{s}", .{ "warn" });
    std.log.err("{s}", .{ "err" });

    try window.init(640, 480, "example");
    defer window.deinit();

    while (!window.shouldClose())
    {
        
    }
}

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void 
{
    const terminal_red = "\x1B[31m";
    const terminal_yellow = "\x1B[33m";
    const terminal_blue = "\x1B[34m";
    const terminal_green = "\x1B[32m";

    const color_begin = switch (message_level)
    {
        .err => terminal_red,
        .warn => terminal_yellow,
        .info => terminal_blue,
        .debug => terminal_green,
    };

    const color_end = "\x1B[0;39m";

    const level_txt = "[" ++ color_begin ++ comptime message_level.asText() ++ color_end ++ "]";
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const stderr = std.io.getStdErr().writer();
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    nosuspend stderr.print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;
}