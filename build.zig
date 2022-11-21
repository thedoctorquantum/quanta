const std = @import("std");

const glfw = @import("quanta/lib/mach-glfw/build.zig");

const quanta = @import("quanta/src/main.zig");
// const png = quanta.asset.importers.png;

fn compileShader(builder: *std.build.Builder, mode: std.builtin.Mode, comptime stage: []const u8, comptime source: []const u8, comptime output: []const u8) !std.build.GeneratedFile 
{
    return switch (mode)
    {
        .Debug => compileShaderSpecialized(builder, .Debug, stage, source, output),
        .ReleaseFast => compileShaderSpecialized(builder, .ReleaseFast, stage, source, output),
        .ReleaseSafe => compileShaderSpecialized(builder, .ReleaseSafe, stage, source, output),
        .ReleaseSmall => compileShaderSpecialized(builder, .ReleaseSmall, stage, source, output),
    };
}

fn compileShaderSpecialized(
    builder: *std.build.Builder, 
    comptime mode: std.builtin.Mode, 
    comptime stage: []const u8, 
    comptime source: []const u8, 
    comptime output: []const u8
) !std.build.GeneratedFile
{
    const shader_target = "vulkan1.2";

    const shader_optimisation = switch (mode)
    {
        //TODO: -O causes a crash in our spirv parsing code 
        .ReleaseFast => "-O0",
        .ReleaseSafe => "-O",
        .ReleaseSmall => "-O0",
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

    return std.build.GeneratedFile 
    { 
        .step = &builder.addSystemCommand(args).step,
        .path = output,
    };
}

pub const PreBuildResult = struct 
{
    options_package: std.build.Pkg,
};

///Only needs to be called once per zig build invocation
fn preBuildQuanta(mode: std.builtin.Mode, builder: *std.build.Builder) !PreBuildResult 
{
    var result: PreBuildResult = undefined;

    // const tri_vert_path = "quanta/src/renderer/spirv/tri.vert.spv";

    const shaders_directory_path = "zig-out/bin/shaders/";

    std.fs.cwd().makeDir(shaders_directory_path) catch {};

    const renderer_tri_vert_glsl = try compileShader(builder, mode, "vert", "quanta/src/renderer/tri.vert.glsl", shaders_directory_path ++ "tri.vert.spv");
    const renderer_tri_frag_glsl = try compileShader(builder, mode, "frag", "quanta/src/renderer/tri.frag.glsl", "quanta/src/renderer/spirv/tri.frag.spv");
    const renderer_depth_vert_glsl = try compileShader(builder, mode, "vert", "quanta/src/renderer/depth.vert.glsl", "quanta/src/renderer/spirv/depth.vert.spv");
    const renderer_depth_frag_glsl = try compileShader(builder, mode, "frag", "quanta/src/renderer/depth.frag.glsl", "quanta/src/renderer/spirv/depth.frag.spv");
    const renderer_cull_comp_glsl = try compileShader(builder, mode, "comp", "quanta/src/renderer/cull.comp.glsl", "quanta/src/renderer/spirv/cull.comp.spv");
    const renderer_depth_reduce_comp_glsl = try compileShader(builder, mode, "comp", "quanta/src/renderer/depth_reduce.comp.glsl", "quanta/src/renderer/spirv/depth_reduce.comp.spv");

    const renderer_gui_rectangle_vert_glsl = try compileShader(builder, mode, "vert", "quanta/src/renderer_gui/rectangle.vert.glsl", "quanta/src/renderer_gui/spirv/rectangle.vert.spv");
    const renderer_gui_rectangle_frag_glsl = try compileShader(builder, mode, "frag", "quanta/src/renderer_gui/rectangle.frag.glsl", "quanta/src/renderer_gui/spirv/rectangle.frag.spv");
    const renderer_gui_mesh_vert_glsl = try compileShader(builder, mode, "vert", "quanta/src/renderer_gui/mesh.vert.glsl", "quanta/src/renderer_gui/spirv/mesh.vert.spv");
    const renderer_gui_mesh_frag_glsl = try compileShader(builder, mode, "frag", "quanta/src/renderer_gui/mesh.frag.glsl", "quanta/src/renderer_gui/spirv/mesh.frag.spv");

    const options = builder.addOptions();

    options.step.dependOn(renderer_tri_vert_glsl.step);
    options.step.dependOn(renderer_tri_frag_glsl.step);
    options.step.dependOn(renderer_depth_vert_glsl.step);
    options.step.dependOn(renderer_depth_frag_glsl.step);
    options.step.dependOn(renderer_cull_comp_glsl.step);
    options.step.dependOn(renderer_depth_reduce_comp_glsl.step);
    options.step.dependOn(renderer_gui_rectangle_vert_glsl.step);
    options.step.dependOn(renderer_gui_rectangle_frag_glsl.step);
    options.step.dependOn(renderer_gui_mesh_vert_glsl.step);
    options.step.dependOn(renderer_gui_mesh_frag_glsl.step);

    options.addOptionFileSource("renderer_tri_vert_spv_path", std.build.FileSource.relative(shaders_directory_path ++ "tri.vert.spv"));
    options.addOption([]const u8, "renderer_tri_frag_spv_path", "spirv/tri.frag.spv");

    result.options_package = options.getPackage("options");

    return result;
}

fn buildQuanta(builder: *std.build.Builder, exe: *std.build.LibExeObjStep, pre_build: PreBuildResult) !void 
{
    _ = builder;

    exe.addCSourceFile("quanta/src/asset/importers/cgltf.c", &[_][]const u8 {});

    {
        var package = std.build.Pkg 
        {
            .name = "quanta",
            .source = .{ .path = "quanta/src/main.zig" },
            .dependencies = &.{
                pre_build.options_package,
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
                std.build.Pkg
                {
                    .name = "renderer_shaders",
                    .source = .{ .path = "zig-out/bin/shaders/shaders.zig" },
                }
            },
        };

        exe.addPackage(package);
        exe.addIncludePath("quanta/lib/Nuklear/");
        exe.addCSourceFile("quanta/src/nuklear/nuklear.c", &[_][]const u8 {});
        exe.addIncludePath("lib/cimgui/imgui/");
        exe.addCSourceFiles(&[_][]const u8 {
            "quanta/lib/cimgui/imgui/imgui.cpp",
            "quanta/lib/cimgui/imgui/imgui_draw.cpp",
            "quanta/lib/cimgui/imgui/imgui_tables.cpp",
            "quanta/lib/cimgui/imgui/imgui_widgets.cpp",
            "quanta/lib/cimgui/imgui/imgui_demo.cpp",
            "quanta/lib/cimgui/cimgui.cpp",
        }, &[_][]const u8 {});
        exe.linkLibCpp();

        try glfw.link(exe.builder, exe, .{});
    }
}

pub fn build(builder: *std.build.Builder) !void 
{
    const target = builder.standardTargetOptions(.{});
    const mode = builder.standardReleaseOptions();

    const quanta_prebuild = try preBuildQuanta(mode, builder);

    //example asset build
    {
        const exe = builder.addExecutable("example_assets", "example/src/asset_build.zig");

        //technically should be the target the build is running on
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();

        try buildQuanta(builder, exe, quanta_prebuild);

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

        try buildQuanta(builder, exe, quanta_prebuild);

        if (mode == .ReleaseFast or mode == .ReleaseSmall)
        {
            exe.strip = true;
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
