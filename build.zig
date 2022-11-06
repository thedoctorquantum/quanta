const std = @import("std");

const glfw = @import("quanta/lib/mach-glfw/build.zig");

const quanta = @import("quanta/src/main.zig");
// const png = quanta.asset.importers.png;

fn compileShader(builder: *std.build.Builder, mode: std.builtin.Mode, comptime stage: []const u8, comptime source: []const u8, comptime output: []const u8) !void 
{
    const shader_target = "vulkan1.3";
    const shader_source_directory = "example/src/shaders/";
    const shader_binary_directory = "example/src/shaders/spirv/";

    const shader_optimisation = switch (mode)
    {
        .ReleaseFast => "-O",
        .ReleaseSafe => "-O",
        .ReleaseSmall => "-Os",
        .Debug => "-O0",
    };

    try builder.spawnChild(
        &[_][]const u8 
        { 
            "glslc", 
            "--target-env=" ++ shader_target, 
            "-fshader-stage=" ++ stage, 
            shader_source_directory ++ source, 
            "-Werror", 
            "-c", 
            shader_optimisation, 
            "-o", 
            shader_binary_directory ++ output
        }
    );
}

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
                    std.build.Pkg
                    {
                        .name = "zigimg",
                        .source = .{ .path = "quanta/lib/zigimg/zigimg.zig" }
                    },
                },
            };

            exe.addPackage(package);

            try glfw.link(exe.builder, exe, .{});
        }

        // var tileset = try png.importFile(builder.allocator, "example/src/assets/tileset.png");
        // defer png.free(&tileset, builder.allocator);

        // const assets_options = builder.addOptions();

        // // assets_options.addOption([]const u8, "tileset_data", tileset.data);
        // // assets_options.addOption(u32, "tileset_width", tileset.width);
        // // assets_options.addOption(u32, "tileset_height", tileset.height);

        // exe.addOptions("assets", assets_options);

        if (mode == .ReleaseFast or mode == .ReleaseSmall)
        {
            exe.strip = true;
        }

        try compileShader(builder, mode, "vert", "tri.vert.glsl", "tri.vert.spv");
        try compileShader(builder, mode, "frag", "tri.frag.glsl", "tri.frag.spv");

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
