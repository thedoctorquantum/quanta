const std = @import("std");

const vkgen = @import("lib/vulkan-zig/generator/index.zig");
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
                    glfw.pkg,
                },
            };

            exe.addPackage(package);

            try glfw.link(exe.builder, exe, .{});
        }

        if (mode == .ReleaseFast)
        {
            exe.strip = true;
        }

        const shader_optimisation = switch (mode)
        {
            .ReleaseFast => "-O",
            .ReleaseSafe => "-O",
            .ReleaseSmall => "-Os",
            .Debug => "-O0",
        };

        const shader_target = "vulkan1.3";
        const shader_source_directory = "example/src/shaders/";
        const shader_binary_directory = "example/src/shaders/spirv/";

        std.fs.cwd().makeDir(shader_binary_directory) catch {};

        try builder.spawnChild(&[_][]const u8 { "glslc", "--target-env=" ++ shader_target, "-fshader-stage=vert", shader_source_directory ++ "tri.vert.glsl", "-Werror", "-c", shader_optimisation, "-o", shader_binary_directory ++ "tri.vert.spv" });
        try builder.spawnChild(&[_][]const u8 { "glslc", "--target-env=" ++ shader_target, "-fshader-stage=frag", shader_source_directory ++ "tri.frag.glsl", "-Werror", "-c", shader_optimisation, "-o", shader_binary_directory ++ "tri.frag.spv" }); 

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
