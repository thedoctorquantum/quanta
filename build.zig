const std = @import("std");

const quanta = @import("quanta/build.zig");
const example = @import("example/build.zig");

pub fn build(builder: *std.build.Builder) !void 
{
    const target = builder.standardTargetOptions(.{});
    const mode = builder.standardReleaseOptions();

    try example.build(builder, target, mode);
}
