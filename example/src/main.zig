const std = @import("std");
const builtin = @import("builtin");
const quanta = @import("quanta");
const windowing = quanta.windowing;
const window = quanta.windowing.window;
const GraphicsContext = quanta.graphics.Context;
const Swapchain = quanta.graphics.Swapchain;
const CommandBuffer = quanta.graphics.CommandBuffer;
const GraphicsPipeline = quanta.graphics.GraphicsPipeline;
const Buffer = quanta.graphics.Buffer;
const Image = quanta.graphics.Image;
const Sampler = quanta.graphics.Sampler;
const png = quanta.asset.importers.png;
const vk = quanta.graphics.vulkan;

const graphics = quanta.graphics;
const Renderer3D = quanta.renderer.Renderer3D;

const shaders = @import("shaders.zig");
const assets = @import("assets");

fn packUnorm4x8(v: [4]f32) u32
{
    const Unorm4x8 = packed struct(u32)
    {
        x: u8,
        y: u8,
        z: u8,
        w: u8,
    };

    const x = @floatToInt(u8, v[0] * @intToFloat(f32, std.math.maxInt(u8)));
    const y = @floatToInt(u8, v[1] * @intToFloat(f32, std.math.maxInt(u8)));
    const z = @floatToInt(u8, v[2] * @intToFloat(f32, std.math.maxInt(u8)));
    const w = @floatToInt(u8, v[3] * @intToFloat(f32, std.math.maxInt(u8)));

    return @bitCast(u32, Unorm4x8 {
        .x = x,
        .y = y,
        .z = z, 
        .w = w,
    });
}

pub fn main() !void 
{
    std.log.debug("All your {s} are belong to us.", .{ "codebase" });
    std.log.debug("{s}", .{ "debug" });
    std.log.warn("{s}", .{ "warn" });
    std.log.err("{s}", .{ "err" });

    var gpa = if (builtin.mode == .Debug)
        std.heap.GeneralPurposeAllocator(.{}) {}
    else {};
    defer if (builtin.mode == .Debug) std.debug.assert(!gpa.deinit());

    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

    try window.init(640, 480, "Quanta Example");
    defer window.deinit();

    const pipeline_cache_file_path = "pipeline_cache";

    {
        var pipeline_cache_data: []u8 = &[_]u8 {};

        const file = std.fs.cwd().openFile(pipeline_cache_file_path, .{}) catch try std.fs.cwd().createFile(pipeline_cache_file_path, .{ .read = true });
        defer file.close();

        pipeline_cache_data = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(pipeline_cache_data);

        std.log.debug("pipeline_cache_data.len = {}", .{ pipeline_cache_data.len });

        try GraphicsContext.init(allocator, pipeline_cache_data);
    }

    defer GraphicsContext.deinit();

    defer 
    {
        const pipeline_cache_data = GraphicsContext.getPipelineCacheData() catch unreachable;
        defer allocator.free(pipeline_cache_data);

        const file = std.fs.cwd().openFile(pipeline_cache_file_path, .{ .mode = .write_only }) catch unreachable;
        defer file.close();

        file.seekTo(0) catch unreachable;

        file.writeAll(pipeline_cache_data) catch unreachable;
    }

    var swapchain = try Swapchain.init(allocator, .{ .width = 640, .height = 480 });
    defer swapchain.deinit();

    try Renderer3D.init(allocator, &swapchain);
    defer Renderer3D.deinit();

    const tileset_import = try png.import(allocator, @embedFile("assets/tileset.png"));
    defer allocator.free(tileset_import.data);

    const wood_floor_import = try png.import(allocator, @embedFile("assets/wood_floor.png"));
    defer allocator.free(wood_floor_import.data);

    const triangle_mesh = try Renderer3D.createMesh(
        &[_]Renderer3D.Vertex
        {
            .{  
                .position = .{ 0.5, 0.5, 0 },
                .normal = .{ 0, 0, 0 },
                .color = packUnorm4x8(.{ 1, 0, 0, 1}),
                .uv = .{ 0, 0 },
            },
            .{  
                .position = .{ -0.5, 0.5, 0 },
                .normal = .{ 0, 0, 0 },
                .color = packUnorm4x8(.{ 0, 1, 0, 1}),
                .uv = .{ 1, 0 },
            },
            .{  
                .position = .{ 0, -0.5, 0 },
                .normal = .{ 0, 0, 0 },
                .color = packUnorm4x8(.{ 0, 0, 1, 0.25}),
                .uv = .{ 0.5, 1 },
            },
        }, 
        &[_]u32 { 0, 1, 2 },
    );

    const second_mesh = try Renderer3D.createMesh(
        &[_]Renderer3D.Vertex
        {
            .{  
                .position = .{ 0.5, 0.5, 0 },
                .normal = .{ 0, 0, 0 },
                .color = packUnorm4x8(.{ 1, 1, 1, 1}),
                .uv = .{ 0, 0 },
            },
            .{  
                .position = .{ -0.5, 0.5, 0 },
                .normal = .{ 0, 0, 0 },
                .color = packUnorm4x8(.{ 1, 1, 1, 1}),
                .uv = .{ 1, 0 },
            },
            .{  
                .position = .{ 0, -0.5, 0 },
                .normal = .{ 0, 0, 0 },
                .color = packUnorm4x8(.{ 1, 1, 1, 1}),
                .uv = .{ 0.5, 1 },
            },
        }, 
        &[_]u32 { 0, 1, 2 },
    );

    const material2 = try Renderer3D.createMaterial(
        wood_floor_import.data, 
        wood_floor_import.width, 
        wood_floor_import.height, 
        .{ 1, 0.4, 0.4, 1 }
    );

    const material = try Renderer3D.createMaterial(
        tileset_import.data, 
        tileset_import.width, 
        tileset_import.height, 
        .{ 1, 1, 1, 1 }
    );

    const time_start = std.time.milliTimestamp();

    const target_frame_time: i64 = 16; 

    var delta_time: i64 = 0;

    while (!window.shouldClose())
    {
        const time_begin = std.time.milliTimestamp();

        defer 
        {
            delta_time = std.time.milliTimestamp() - time_begin;
            
            if (delta_time < target_frame_time)
            {
                //Slow down the game loop
                std.time.sleep(@intCast(u64, (target_frame_time - delta_time) * std.time.ns_per_ms));
            }
        }

        const time = std.time.milliTimestamp() - time_start;

        {
            Renderer3D.beginRender();
            defer Renderer3D.endRender() catch unreachable;

            const y_offset = std.math.sin(@intToFloat(f32, time) * 0.001);

            Renderer3D.drawMesh(triangle_mesh, material, quanta.math.zalgebra.Mat4.fromTranslate(
                .{  
                    .data = .{ 0, y_offset, 0 }
                }
            ));

            Renderer3D.drawMesh(second_mesh, material2, quanta.math.zalgebra.Mat4.fromRotation(
                y_offset * 60,
                .{  
                    .data = .{ 1, 0, 0 }
                }
            ));
        }
    }

    try GraphicsContext.self.vkd.deviceWaitIdle(GraphicsContext.self.device);
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