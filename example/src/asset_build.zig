const std = @import("std");
const quanta = @import("quanta");
const asset = quanta.asset;
const gltf = quanta.asset.importers.gltf;
const png = quanta.asset.importers.png;

pub fn main() !void 
{
    std.log.info("Building assets:", .{});

    const cache_directory = "zig-out/bin/assets/";

    std.fs.cwd().makeDir(cache_directory) catch {};

    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};

    const allocator = gpa.allocator();

    var assets = std.ArrayListUnmanaged(asset.Archive.AssetDescription) {};
    defer assets.deinit(allocator);

    if (true)
    {   
        const sponza = try gltf.import(allocator, "example/src/assets/sponza/Sponza.gltf");
        defer gltf.importFree(sponza, allocator);
    
        const sponza_encoded = try gltf.encode(allocator, sponza);    

        try assets.append(allocator, .{
            .source_data = sponza_encoded,
            .source_data_alignment = @alignOf(gltf.ImportBinHeader),
            .mapped_data_size = sponza_encoded.len,
        });
    }

    const gm_construct_bsp = try quanta.asset.importers.bsp.importFile(allocator, "example/src/assets/gm_construct.bsp");
    defer quanta.asset.importers.bsp.importFree(allocator, gm_construct_bsp);

    const gm_construct_gltf = try quanta.asset.importers.bsp.convertToGltfImport(allocator, gm_construct_bsp);

    const gm_construct_gltf_encoded = try gltf.encode(allocator, gm_construct_gltf);

    try assets.append(allocator, .{
        .source_data = gm_construct_gltf_encoded,
        .source_data_alignment = @alignOf(gltf.ImportBinHeader),
        .mapped_data_size = gm_construct_gltf_encoded.len,
    });

    const gm_castle_island_bsp = try quanta.asset.importers.bsp.importFile(allocator, "example/src/assets/gm_castle_island.bsp");
    defer quanta.asset.importers.bsp.importFree(allocator, gm_castle_island_bsp);

    const gm_castle_island_gltf = try quanta.asset.importers.bsp.convertToGltfImport(allocator, gm_castle_island_bsp);

    const gm_castle_island_gltf_encoded = try gltf.encode(allocator, gm_castle_island_gltf);

    try assets.append(allocator, .{
        .source_data = gm_castle_island_gltf_encoded,
        .source_data_alignment = @alignOf(gltf.ImportBinHeader),
        .mapped_data_size = gm_castle_island_gltf_encoded.len,
    });

    var environment_map = try png.importCubeFile(
        allocator, 
        [_][]const u8
        {
            "example/src/assets/skybox/right.png", //x+
            "example/src/assets/skybox/left.png", //x-
            "example/src/assets/skybox/top.png", //y+
            "example/src/assets/skybox/bottom.png", //y-
            "example/src/assets/skybox/back.png", //z+
            "example/src/assets/skybox/front.png", //z-
        }
    ); 
    defer png.free(&environment_map, allocator);

    try assets.append(allocator, .{
        .source_data = environment_map.data,
        .source_data_alignment = @alignOf(u32),
        .mapped_data_size = environment_map.data.len,
    });

    const asset_archive = try asset.Archive.encode(allocator, assets.items);

    const asset_archive_file = std.fs.cwd().openFile(cache_directory ++ "example_assets_archive", .{ .mode = .write_only }) catch try std.fs.cwd().createFile(cache_directory ++ "example_assets_archive", .{});
    defer asset_archive_file.close();

    try asset_archive_file.writeAll(asset_archive);
}