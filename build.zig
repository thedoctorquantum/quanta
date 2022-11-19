const std = @import("std");

const glfw = @import("quanta/lib/mach-glfw/build.zig");

const quanta = @import("quanta/src/main.zig");
// const png = quanta.asset.importers.png;

fn compileShader(builder: *std.build.Builder, mode: std.builtin.Mode, comptime stage: []const u8, comptime source: []const u8, comptime output: []const u8) !void 
{
    return switch (mode)
    {
        .Debug => compileShaderSpecialized(builder, .Debug, stage, source, output),
        .ReleaseFast => compileShaderSpecialized(builder, .ReleaseFast, stage, source, output),
        .ReleaseSafe => compileShaderSpecialized(builder, .ReleaseSafe, stage, source, output),
        .ReleaseSmall => compileShaderSpecialized(builder, .ReleaseSmall, stage, source, output),
    };
}

fn compileShaderSpecialized(builder: *std.build.Builder, comptime mode: std.builtin.Mode, comptime stage: []const u8, comptime source: []const u8, comptime output: []const u8) !void 
{
    const shader_target = "vulkan1.2";

    const shader_optimisation = switch (mode)
    {
        //TODO: -O causes a crash in our spirv parsing code 
        .ReleaseFast => "-O0",
        .ReleaseSafe => "-O",
        .ReleaseSmall => "-Os",
        .Debug => "-O0",
    };

    comptime var args: []const []const u8 = &.{};

    args = args ++ &[_][]const u8 
    { 
        "glslc", 
        "--target-env=" ++ shader_target, 
        "-fshader-stage=" ++ stage, 
        source, 
        "-Werror", 
        "-c", 
        shader_optimisation, 
    };

    if (mode == .Debug or true)
    {
        args = args ++ &[_][]const u8 
        {
            "-g"
        };
    }

    args = args ++ &[_][]const u8 
    {
        "-o", 
        output
    };

    try builder.spawnChild(args);
}

fn buildQuanta(builder: *std.build.Builder, exe: *std.build.LibExeObjStep) !void 
{
    _ = builder;

    exe.addCSourceFile("quanta/src/asset/importers/cgltf.c", &[_][]const u8 {});
    exe.force_pic = true;

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
                std.build.Pkg
                {
                    .name = "zalgebra",
                    .source = .{ .path = "quanta/lib/zalgebra/src/main.zig" }
                },
            },
        };

        exe.addPackage(package);
        exe.addIncludePath("quanta/lib/Nuklear/");
        exe.addCSourceFile("quanta/src/nuklear/nuklear.c", &[_][]const u8 {});

        try glfw.link(exe.builder, exe, .{});
    }
}

pub fn build(builder: *std.build.Builder) !void 
{
    const target = builder.standardTargetOptions(.{});
    const mode = builder.standardReleaseOptions();

    //example asset build
    {
        const exe = builder.addExecutable("example_assets", "example/src/asset_build.zig");

        //technically should be the target the build is running on
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();

        try buildQuanta(builder, exe);

        const run_cmd = exe.run();

        run_cmd.step.dependOn(builder.getInstallStep());

        const run_step = builder.step("build_assets", "Build example assets");
        run_step.dependOn(&run_cmd.step);
    }

    //example
    {
        const exe = builder.addExecutable("example", "example/src/main.zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();

        try buildQuanta(builder, exe);

        if (mode == .ReleaseFast or mode == .ReleaseSmall)
        {
            exe.strip = true;
        }

        try compileShader(builder, mode, "vert", "quanta/src/renderer/tri.vert.glsl", "quanta/src/renderer/spirv/tri.vert.spv");
        try compileShader(builder, mode, "frag", "quanta/src/renderer/tri.frag.glsl", "quanta/src/renderer/spirv/tri.frag.spv");
        try compileShader(builder, mode, "vert", "quanta/src/renderer/depth.vert.glsl", "quanta/src/renderer/spirv/depth.vert.spv");
        try compileShader(builder, mode, "frag", "quanta/src/renderer/depth.frag.glsl", "quanta/src/renderer/spirv/depth.frag.spv");
        try compileShader(builder, mode, "comp", "quanta/src/renderer/cull.comp.glsl", "quanta/src/renderer/spirv/cull.comp.spv");
        try compileShader(builder, mode, "comp", "quanta/src/renderer/depth_reduce.comp.glsl", "quanta/src/renderer/spirv/depth_reduce.comp.spv");

        try compileShader(builder, mode, "vert", "quanta/src/renderer_gui/rectangle.vert.glsl", "quanta/src/renderer_gui/spirv/rectangle.vert.spv");
        try compileShader(builder, mode, "frag", "quanta/src/renderer_gui/rectangle.frag.glsl", "quanta/src/renderer_gui/spirv/rectangle.frag.spv");
        try compileShader(builder, mode, "vert", "quanta/src/renderer_gui/mesh.vert.glsl", "quanta/src/renderer_gui/spirv/mesh.vert.spv");
        try compileShader(builder, mode, "frag", "quanta/src/renderer_gui/mesh.frag.glsl", "quanta/src/renderer_gui/spirv/mesh.frag.spv");

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
