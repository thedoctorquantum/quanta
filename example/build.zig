const std = @import("std");
const quanta = @import("../quanta/build.zig");

pub fn build(builder: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode) !void 
{
    const exe = builder.addExecutable("example", "example/src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    try quanta.link(exe);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(builder.getInstallStep());

    if (builder.args) |args| 
    {
        run_cmd.addArgs(args);
    }

    const run_step = builder.step("run_example", "Run the example application");
    run_step.dependOn(&run_cmd.step);
}