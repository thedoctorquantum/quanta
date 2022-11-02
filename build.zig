const std = @import("std");

const glfw = @import("lib/mach-glfw/build.zig");

pub fn build(builder: *std.build.Builder) !void 
{
    const target = builder.standardTargetOptions(.{});
    const mode = builder.standardReleaseOptions();

    //example
    {
        const exe = builder.addExecutable("example", "example/src/main.zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();

        {
            var package = std.build.Pkg 
            {
                .name = "quanta",
                .source = .{ .path = "quanta/src/main.zig" },
                .dependencies = &.{
                    glfw.pkg
                },
            };

            exe.addPackage(package);

            try glfw.link(exe.builder, exe, .{});
        }

        const run_cmd = exe.run();
        run_cmd.step.dependOn(builder.getInstallStep());

        if (builder.args) |args| 
        {
            run_cmd.addArgs(args);
        }

        const run_step = builder.step("run_example", "Run the example application");
        run_step.dependOn(&run_cmd.step);
    }
}
