const std = @import("std");
const log = std.log.scoped(.bsp);

pub const Lump = extern struct 
{
	fileofs: i32,      // offset into file (bytes)
	filelen: u32,      // length of lump (bytes)
	version: u32,      // lump format version
	fourCC: [4]u8,    // lump ident code
};

pub const LumpType = enum(u8)
{
    entities = 0,
    planes = 1,
    tex_data = 2,
    vertexes = 3,
    visibility = 4,
    nodes = 5,
    tex_info = 6,
    faces = 7,
    lighting = 8,
    occlusion = 9,
    leafs = 10,
    face_ids = 11,
    edges = 12,
    surfedges = 13,
    models = 14,
    world_lights = 15,
    leaf_faces = 16,
    leaf_brushes = 17,
    brushes = 18,
    brush_sides = 19,
    areas = 20,
    area_portals = 21,
    portals = 22,
    disp_verts = 33,
    dispinfo = 26,
    // unused0 = 23,
    // prop_collision = 24,
    pak_file = 40,
    _,
};

pub const Header = extern struct 
{
    ident: u32,
    version: u32, 
    lumps: [lump_count]Lump,
    map_revision: u32,

    pub const lump_count = 64;
    pub const identifier = @bitCast(u32, @as([4]u8, "VBSP".*));
};

comptime {
    std.debug.assert(@sizeOf(Header) == 1036);
}

pub const ImportResult = struct 
{
    vertices: []Vertex,
    indices: []u16,
};

pub const SurfFlags = packed struct(u32) 
{
    light: bool,
    sky2d: bool,
    sky: bool,
    warp: bool,
    trans: bool,
    no_portal: bool,
    trigger: bool,
    no_draw: bool,
    hint: bool,
    skip: bool,
    no_light: bool,
    bump_light: bool,
    no_shadows: bool,
    no_decals: bool,
    no_chop: bool,
    hit_box: bool,
    
    pad: u16,
};

pub const TexInfo = extern struct 
{
    texture_vecs: [2][4]f32,
    lightmap_vecs: [2][4]f32,
    flags: SurfFlags,
    tex_data: u32, 
};

pub const Vertex = extern struct 
{
    x: f32,
    y: f32,
    z: f32,  
};

pub const Edge = extern struct 
{
    v: [2]u16,
};

pub const Plane = extern struct 
{
    normal: [3]f32,
    dist: f32,
    type: f32,
};

pub const Face = extern struct 
{
	planenum: u16,              // the plane number
	side: u8,                   // faces opposite to the node's plane direction
	onNode: u8,                 // 1 of on node, 0 if in leaf
	firstedge: i32,             // index into surfedges
	numedges: i16,              // number of surfedges
	texinfo: i16,               // texture info
	dispinfo: i16,              // displacement info
	surfaceFogVolumeID: i16,    // ?
	styles: [4]u8,              // switchable lighting info
	lightofs: i32,              // offset into lightmap lump
	area: f32,                  // face area in units^2
	LightmapTextureMinsInLuxels: [2]i32, // texture lighting info
	LightmapTextureSizeInLuxels: [2]i32, // texture lighting info
	origFace: i32,              // original face this was split from
	numPrims: u16,              // primitives
	firstPrimID: u16,
	smoothingGroups: u32,       // lightmap smoothing group

    comptime {
        std.debug.assert(@sizeOf(@This()) == 56);
    }
};

const DispInfo = extern struct
{
	startPosition: [3]f32,                // start position used for orientation
	DispVertStart: i32,                // Index into LUMP_DISP_VERTS.
	DispTriStart: i32,                 // Index into LUMP_DISP_TRIS.
	power: i32,                        // power - indicates size of surface (2^power 1)
	minTess: i32,                      // minimum tesselation allowed
	smoothingAngle: f32,               // lighting smoothing angle
	contents: i32,                     // surface contents
	MapFace: u16,                      // Which map face this displacement comes from.
	LightmapAlphaStart: u32,           // Index into ddisplightmapalpha.
	LightmapSamplePositionStart: u32,  // Index into LUMP_DISP_LIGHTMAP_SAMPLE_POSITIONS.
    EdgeNeighbors: [4]DispNeighbour,             // Indexed by NEIGHBOREDGE_ defines.
	CornerNeighbors: [4]DispCornerNeighbours,           // Indexed by CORNER_ defines.
	AllowedVerts: [10]u32,             // active verticies
};

comptime
{
    std.debug.assert(@sizeOf(DispInfo) == 176);
}

const DispSubNeighbour = extern struct
{
    index: u16 = 0xFFFF,
    orientation: u8,
    span: u8,
    neighbourSpan: u8,
};

const DispNeighbour = extern struct
{
    subNeighbors: [2]DispSubNeighbour,
};

const DispCornerNeighbours = extern struct
{
    neighbours: [4]u16,
    numNeighbours: u8,
};

pub fn importFile(allocator: std.mem.Allocator, file_path: []const u8) !ImportResult 
{
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const data = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    return try import(allocator, data);
}

pub fn import(allocator: std.mem.Allocator, data: []const u8) !ImportResult 
{
    var result = ImportResult 
    {
        .vertices = &.{},
        .indices = &.{},
    };

    var read_head: usize = 0;
    const header = @ptrCast(*const Header, @alignCast(@alignOf(Header), data.ptr)).*;
    read_head += @sizeOf(Header);

    if (header.ident != Header.identifier)
    {
        return error.InvalidIdentifer;
    }

    //The bsp versions can vary wildly, and so different decoding functions may need
    //to be dispatched on this version
    log.info("header_version {}", .{ header.version });
    log.info("header_revision {}", .{ header.map_revision });

    log.info("brushes lump: {}", .{ header.lumps[@enumToInt(LumpType.brushes)] });
    log.info("entities lump: {}", .{ header.lumps[@enumToInt(LumpType.entities)] });
    log.info("pak_file lump: {}", .{ header.lumps[@enumToInt(LumpType.pak_file)] });
    log.info("vertexes lump: {}", .{ header.lumps[@enumToInt(LumpType.vertexes)] });
    log.info("surfedges lump: {}", .{ header.lumps[@enumToInt(LumpType.surfedges)] });

    const vertexes_offset = @intCast(usize, header.lumps[@enumToInt(LumpType.vertexes)].fileofs);
    const vertexes_length = header.lumps[@enumToInt(LumpType.vertexes)].filelen / @sizeOf(Vertex); 
    const vertexes = @ptrCast([*]const Vertex, @alignCast(@alignOf(Vertex), data.ptr + vertexes_offset))[0..vertexes_length];

    log.info("vertexes.len = {}", .{ vertexes.len });
    log.info("vertexes[0] = {}", .{ vertexes[0] });
    log.info("vertexes[1] = {}", .{ vertexes[1] });
    log.info("vertexes[2] = {}", .{ vertexes[2] });

    const edges_offset = @intCast(usize, header.lumps[@enumToInt(LumpType.edges)].fileofs);
    const edges_length = header.lumps[@enumToInt(LumpType.edges)].filelen / @sizeOf(Edge); 
    const edges = @ptrCast([*]const Edge, @alignCast(@alignOf(Edge), data.ptr + edges_offset))[0..edges_length];

    result.vertices = try allocator.alloc(Vertex, vertexes.len);
    errdefer allocator.free(result.vertices);

    for (result.vertices) |*vertex, i|
    {
        //Correct the coordinate space
        vertex.x = vertexes[i].x;
        vertex.y = vertexes[i].z;
        vertex.z = -vertexes[i].y;
    }

    const surfedges_offset = @intCast(usize, header.lumps[@enumToInt(LumpType.surfedges)].fileofs);
    const surfedges_length = header.lumps[@enumToInt(LumpType.surfedges)].filelen / @sizeOf(i32); 
    const surfedges = @ptrCast([*]const i32, @alignCast(@alignOf(i32), data.ptr + surfedges_offset))[0..surfedges_length];

    const dispinfos_offset = @intCast(usize, header.lumps[@enumToInt(LumpType.dispinfo)].fileofs);
    const dispinfos_length = header.lumps[@enumToInt(LumpType.dispinfo)].filelen / @sizeOf(DispInfo); 
    const dispinfos = @ptrCast([*]const DispInfo, @alignCast(@alignOf(DispInfo), data.ptr + dispinfos_offset))[0..dispinfos_length];

    log.info("surfedges.len = {}", .{ surfedges.len });

    result.indices = try allocator.alloc(u16, surfedges.len * 2);
    errdefer allocator.free(result.indices);

    const faces_offset = @intCast(usize, header.lumps[@enumToInt(LumpType.faces)].fileofs);
    const faces_length = header.lumps[@enumToInt(LumpType.faces)].filelen / @sizeOf(Face); 
    const faces = @ptrCast([*]const Face, @alignCast(@alignOf(Face), data.ptr + faces_offset))[0..faces_length];

    const tex_infos_offset = @intCast(usize, header.lumps[@enumToInt(LumpType.tex_info)].fileofs);
    const tex_infos_length = header.lumps[@enumToInt(LumpType.tex_info)].filelen / @sizeOf(TexInfo); 
    const tex_infos = @ptrCast([*]const TexInfo, @alignCast(@alignOf(TexInfo), data.ptr + tex_infos_offset))[0..tex_infos_length];

    var current_surfedge: usize = 0; 

    var triangle_count: usize = 0;

    for (faces) |face|
    {
        const tex_info: TexInfo = tex_infos[@intCast(usize, face.texinfo)];

        if (
            tex_info.flags.trigger or 
            tex_info.flags.skip or 
            tex_info.flags.hit_box or 
            tex_info.flags.no_draw or
            tex_info.flags.sky2d or 
            tex_info.flags.sky
        )
        {
            continue;
        }

        if (face.dispinfo < 0)
        {
            triangle_count += @intCast(u32, face.numedges) - 2;
        }
        else 
        { 
            const size = @as(u32, 1) << @intCast(u5, dispinfos[@intCast(usize, face.dispinfo)].power);

            triangle_count += size * size * 2;
        }

        const face_surfedges: []const i32 = surfedges[@intCast(usize, face.firstedge)..@intCast(usize, face.firstedge) + @intCast(usize, face.numedges)];

        for (face_surfedges) |surf_edge, i|
        {
            const edge_index = std.math.absCast(surf_edge);
            const edge: Edge = edges[edge_index];

            const index_index = (current_surfedge + i) * 2;

            if (surf_edge >= 0) 
            {
                result.indices[index_index] = edge.v[0];
                result.indices[index_index + 1] = edge.v[1];
            } 
            else 
            {
                result.indices[index_index] = edge.v[1];
                result.indices[index_index + 1] = edge.v[0];
            }
        }

        current_surfedge += face_surfedges.len;
    }

    return result;
}

pub fn importFree(allocator: std.mem.Allocator, import_result: ImportResult) void 
{
    allocator.free(import_result.vertices);
    allocator.free(import_result.indices);
}

const gltf = @import("gltf.zig");

//Hacky way of getting the geometry into the engine... yuck
pub fn convertToGltfImport(allocator: std.mem.Allocator, import_result: ImportResult) !gltf.Import
{
    var gltf_import_data: gltf.Import = .{
        .vertex_positions = &.{},
        .vertices = &.{},
        .indices = &.{},
        .sub_meshes = &.{},
        .materials = &.{},
        .textures = &.{},
        .point_lights = &.{},
    };

    gltf_import_data.vertex_positions = try allocator.alloc([3]f32, import_result.vertices.len);
    errdefer allocator.free(gltf_import_data.vertex_positions);

    @memcpy(@ptrCast([*]u8, gltf_import_data.vertex_positions.ptr), @ptrCast([*]const u8, import_result.vertices.ptr), import_result.vertices.len * @sizeOf([3]f32));

    gltf_import_data.indices = try allocator.alloc(u32, import_result.indices.len);
    errdefer allocator.free(gltf_import_data.indices);

    for (import_result.indices) |index, i|
    {
        gltf_import_data.indices[i] = index;
    }

    gltf_import_data.vertices = try allocator.alloc(std.meta.Child(@TypeOf(gltf_import_data.vertices)), import_result.vertices.len);
    errdefer allocator.free(gltf_import_data.vertices);

    for (gltf_import_data.vertices) |*vertex|
    {
        vertex.color = std.math.maxInt(u32);
        vertex.uv = .{ 0, 0 };
        vertex.normal = .{ 0, 1, 0 };
    }

    gltf_import_data.materials = try allocator.alloc(std.meta.Child(@TypeOf(gltf_import_data.materials)), 1);
    errdefer allocator.free(gltf_import_data.materials);

    gltf_import_data.materials[0] = .{
        .albedo = .{ 1, 1, 1, 1 },
        .albedo_texture_index = 0, 
    };

    gltf_import_data.sub_meshes = try allocator.alloc(std.meta.Child(@TypeOf(gltf_import_data.sub_meshes)), 1);
    errdefer allocator.free(gltf_import_data.sub_meshes);

    gltf_import_data.sub_meshes[0] = .{
        .vertex_offset = 0,
        .vertex_count = @intCast(u32, import_result.vertices.len),
        .index_offset = 0,
        .index_count = @intCast(u32, import_result.indices.len),
        .material_index = 0,
        .transform = .{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 1 },
        },
        .bounding_min = .{ std.math.f32_min, std.math.f32_min, std.math.f32_min },
        .bounding_max = .{ std.math.f32_max, std.math.f32_max, std.math.f32_max },
    };

    return gltf_import_data;
}