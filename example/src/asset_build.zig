const std = @import("std");
const quanta = @import("quanta");
const gltf = quanta.asset.importers.gltf;

pub fn main() !void 
{
    std.log.info("Building assets:", .{});

    const cache_directory = "zig-out/bin/assets/";

    std.fs.cwd().makeDir(cache_directory) catch {};

    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};

    const allocator = gpa.allocator();

    if (false)
    {   
        const sponza = try gltf.import(allocator, "example/src/assets/test_scene.gltf");
        defer gltf.importFree(sponza, allocator);
    
        const sponza_file = std.fs.cwd().openFile(cache_directory ++ "test_scene", .{ .mode = .write_only }) catch try std.fs.cwd().createFile(cache_directory ++ "test_scene", .{});
        defer sponza_file.close();
    
        try sponza_file.seekTo(0);
    
        const sponza_encoded = try gltf.encode(allocator, sponza);
    
        try sponza_file.writeAll(sponza_encoded);
    }

    const gm_construct_bsp = try quanta.asset.importers.bsp.importFile(allocator, "example/src/assets/gm_construct.bsp");
    defer quanta.asset.importers.bsp.importFree(allocator, gm_construct_bsp);

    const gm_construct_gltf = try quanta.asset.importers.bsp.convertToGltfImport(allocator, gm_construct_bsp);

    const gm_construct_gltf_encoded = try gltf.encode(allocator, gm_construct_gltf);

    const gm_construct_file = std.fs.cwd().openFile(cache_directory ++ "gm_construct", .{ .mode = .write_only }) catch try std.fs.cwd().createFile(cache_directory ++ "gm_construct", .{});
    defer gm_construct_file.close();

    try gm_construct_file.writeAll(gm_construct_gltf_encoded);
}