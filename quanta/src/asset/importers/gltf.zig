const std = @import("std");
const Renderer3D = @import("../../renderer/Renderer3D.zig");
const cgltf = @import("cgltf.zig");
const zalgebra = @import("zalgebra");
const png = @import("png.zig");

pub const Import = struct 
{
    vertex_positions: [][3]f32,
    vertices: []Renderer3D.Vertex,
    indices: []u32,
    sub_meshes: []SubMesh,
    materials: []Material,
    textures: []Texture,
    point_lights: []Renderer3D.PointLight,

    pub const SubMesh = extern struct 
    {
        vertex_offset: u32,
        vertex_count: u32,
        index_offset: u32,
        index_count: u32,
        material_index: u32,
        transform: [4][4]f32,
        bounding_min: [3]f32,
        bounding_max: [3]f32,
    };

    pub const Material = extern struct 
    {
        albedo: [4]f32,
        albedo_texture_index: u32, 
        metalness: f32,
        metalness_texture_index: u32,
        roughness: f32,
        roughness_texture_index: u32,
    };

    pub const Texture = struct 
    {
        data: []u8,
        width: u32,
        height: u32,
    };
};

pub fn import(allocator: std.mem.Allocator, file_path: []const u8) !Import 
{
    @setRuntimeSafety(false);

    var import_data: Import = .{
        .vertex_positions = &.{},
        .vertices = &.{},
        .indices = &.{},
        .sub_meshes = &.{},
        .materials = &.{},
        .textures = &.{},
        .point_lights = &.{},
    };

    var cgltf_data: [*c]cgltf.cgltf_data = null;

    const file_directory_name = std.fs.path.dirname(file_path) orelse unreachable;

    var file_directory = try std.fs.cwd().openDir(file_directory_name, .{});
    defer file_directory.close();

    const file_extension = std.fs.path.extension(file_path);

    std.log.info("file_extension: {s}", .{ file_extension });

    const file_type = if (std.mem.eql(u8, file_extension, ".gltf")) 
        cgltf.cgltf_file_type_gltf
    else if (std.mem.eql(u8, file_extension, ".glb"))
        cgltf.cgltf_file_type_glb
    else unreachable;

    const cgltf_options = cgltf.cgltf_options 
    {
        .type = @intCast(c_uint, file_type),
        .json_token_count = 0,
        .memory = .{
            .alloc_func = null,
            .free_func = null,
            .user_data = null,
        },
        .file = .{
            .read = null,
            .release = null,
            .user_data = null,
        },
    };

    std.log.debug("gltf_path: {s}", .{ file_path });

    switch (cgltf.cgltf_parse_file(&cgltf_options, file_path.ptr, &cgltf_data))
    {
        cgltf.cgltf_result_success => {},
        cgltf.cgltf_result_data_too_short => unreachable,
        cgltf.cgltf_result_unknown_format => unreachable,
        cgltf.cgltf_result_invalid_json => unreachable,
        cgltf.cgltf_result_invalid_gltf => unreachable,
        cgltf.cgltf_result_invalid_options => unreachable,
        cgltf.cgltf_result_file_not_found => unreachable,
        cgltf.cgltf_result_io_error => unreachable,
        cgltf.cgltf_result_out_of_memory => unreachable,
        cgltf.cgltf_result_legacy_gltf => unreachable,
        else => unreachable,
    }
    defer cgltf.cgltf_free(cgltf_data);

    std.debug.assert(cgltf_data != null);

    switch (cgltf.cgltf_load_buffers(&cgltf_options, cgltf_data, file_path.ptr))
    {
        cgltf.cgltf_result_success => {},
        cgltf.cgltf_result_data_too_short => unreachable,
        cgltf.cgltf_result_unknown_format => unreachable,
        cgltf.cgltf_result_invalid_json => unreachable,
        cgltf.cgltf_result_invalid_gltf => unreachable,
        cgltf.cgltf_result_invalid_options => unreachable,
        cgltf.cgltf_result_file_not_found => unreachable,
        cgltf.cgltf_result_io_error => unreachable,
        cgltf.cgltf_result_out_of_memory => unreachable,
        cgltf.cgltf_result_legacy_gltf => unreachable,
        else => unreachable,
    }

    switch (cgltf.cgltf_validate(cgltf_data))
    {
        cgltf.cgltf_result_success => {},
        cgltf.cgltf_result_data_too_short => unreachable,
        cgltf.cgltf_result_unknown_format => unreachable,
        cgltf.cgltf_result_invalid_json => unreachable,
        cgltf.cgltf_result_invalid_gltf => unreachable,
        cgltf.cgltf_result_invalid_options => unreachable,
        cgltf.cgltf_result_file_not_found => unreachable,
        cgltf.cgltf_result_io_error => unreachable,
        cgltf.cgltf_result_out_of_memory => unreachable,
        cgltf.cgltf_result_legacy_gltf => unreachable,
        else => unreachable,
    }

    const texture_count: usize = cgltf_data.*.textures_count;

    var model_vertices = std.ArrayList(Renderer3D.Vertex).init(allocator);
    defer model_vertices.deinit();

    var model_vertex_positions = std.ArrayList([3]f32).init(allocator);
    defer model_vertex_positions.deinit();

    var model_indices = std.ArrayList(u32).init(allocator);
    defer model_indices.deinit();

    var sub_meshes = std.ArrayList(Import.SubMesh).init(allocator);
    defer sub_meshes.deinit();

    var textures = try std.ArrayList(Import.Texture).initCapacity(allocator, texture_count);
    defer textures.deinit();

    var materials = std.ArrayList(Import.Material).init(allocator);
    defer materials.deinit();

    std.log.info("scene_count: {}", .{ cgltf_data.*.scenes_count });
    std.log.info("node_count: {}", .{ cgltf_data.*.nodes_count });
    std.log.info("texture_count: {}", .{ texture_count });

    std.debug.assert(cgltf_data.*.scene != null);

    const gltf_images = if (cgltf_data.*.images == null) &[_]cgltf.cgltf_image {} else cgltf_data.*.images[0..cgltf_data.*.images_count];

    std.log.info("gltf_images.len = {}", .{ gltf_images.len });

    //beware image count and texture count may not be the same 
    for (gltf_images) |image|
    {
        if (image.uri != null)
        {
            const path = std.mem.span(@ptrCast([*:0]u8, image.uri));

            std.log.info("file path: {s}", .{ path });

            const image_file = try file_directory.openFile(path, .{});
            defer image_file.close();

            const raw_data = try image_file.readToEndAlloc(allocator, std.math.maxInt(u64));
            defer allocator.free(raw_data);

            const png_import = try png.import(allocator, raw_data);

            try textures.append(.{
                .data = png_import.data,
                .width = png_import.width,
                .height = png_import.height,
            });
        }
    }

    var point_lights = std.ArrayListUnmanaged(Renderer3D.PointLight) {};
    defer point_lights.deinit(allocator);

    const lights = cgltf_data.*.lights[0..cgltf_data.*.lights_count];

    for (lights) |light|
    {
        switch (light.type)
        {
            cgltf.cgltf_light_type_point => {
                const point_light = Renderer3D.PointLight 
                {
                    .position = .{ 0, -1, 0 },
                    .intensity = light.intensity,
                    .diffuse = packUnorm4x8(.{ light.color[0], light.color[1], light.color[2], 1 }),
                };

                std.log.info("Found point light: {}", .{ point_light });

                try point_lights.append(allocator, point_light);
            },
            else => unreachable,
        }
    }

    const nodes = cgltf_data.*.scene.*.nodes[0..cgltf_data.*.nodes_count - 1];

    std.log.info("Nodes: {}", .{ nodes.len });

    for (nodes) |node_ptr|
    {
        if (node_ptr == null) continue;

        if (node_ptr.*.light != null)
        {
            const light: cgltf.cgltf_light = node_ptr.*.light.*;

            switch (light.type)
            {
                cgltf.cgltf_light_type_point => {
                    const point_light = Renderer3D.PointLight 
                    {
                        .position = node_ptr.*.translation,
                        .intensity = light.intensity,
                        .diffuse = packUnorm4x8(.{ light.color[0], light.color[1], light.color[2], 1 }),
                    };

                    std.log.info("Found point light: {}", .{ point_light });

                    try point_lights.append(allocator, point_light);
                },
                else => unreachable,
            }

            // continue;

            unreachable;
        }

        if (node_ptr.*.mesh == null) continue;

        var transform_matrix: [4][4]f32 = undefined;

        cgltf.cgltf_node_transform_local(node_ptr, @ptrCast([*]f32, &transform_matrix));

        std.debug.assert(node_ptr != null);
        std.debug.assert(node_ptr.*.mesh != null);

        const node = node_ptr.*;
        const mesh = node_ptr.*.mesh.*;

        std.log.info("node.children_count = {}", .{ node.children_count });
        std.log.info("mesh.primitive_count = {}", .{ mesh.primitives_count });

        for (mesh.primitives[0..mesh.primitives_count]) |primitive|
        {
            const vertex_start = model_vertices.items.len;
            const index_start = model_indices.items.len;

            var bounding_min: @Vector(3, f32) = .{ 0, 0, 0 };
            var bounding_max: @Vector(3, f32) = .{ 0, 0, 0 };

            var vertex_count: usize = 0;
            var positions: ?[]const f32 = null; 
            var normals: ?[]const f32 = null; 
            var texture_coordinates: ?[]const f32 = null; 

            for (primitive.attributes[0..primitive.attributes_count]) |attribute|
            {
                if (attribute.data == null) continue;

                const buffer_view = attribute.data.*.buffer_view;

                if (std.cstr.cmp(attribute.name, "POSITION") == 0)
                {
                    vertex_count = attribute.data.*.count;

                    positions = @ptrCast([*]const f32, @alignCast(@alignOf(f32),
                                    @ptrCast([*]u8, buffer_view.*.buffer.*.data.?) + attribute.data.*.offset + buffer_view.*.offset))
                                    [0..attribute.data.*.count * 3];
                }
                else if (std.cstr.cmp(attribute.name, "NORMAL") == 0)
                {
                    normals = @ptrCast([*]const f32, @alignCast(@alignOf(f32),
                                    @ptrCast([*]u8, buffer_view.*.buffer.*.data.?) + attribute.data.*.offset + buffer_view.*.offset))
                                    [0..(attribute.data.*.count * 3)];
                }
                else if (std.cstr.cmp(attribute.name, "TEXCOORD_0") == 0)
                {
                    texture_coordinates = @ptrCast([*]const f32, @alignCast(@alignOf(f32),
                                    @ptrCast([*]u8, buffer_view.*.buffer.*.data.?) + attribute.data.*.offset + buffer_view.*.offset))
                                    [0..(attribute.data.*.count * 2)];
                }
                else if (std.cstr.cmp(attribute.name, "COLOR_0") == 0)
                {
                    unreachable;
                }

                std.log.info("Mesh primitive attribute {s}", .{ attribute.name });
            }

            try model_vertices.ensureTotalCapacity(model_vertices.items.len + vertex_count);

            //Vertices
            {
                var position_index: usize = 0;
                var normal_index: usize = 0;
                var uv_index: usize = 0;

                std.log.info("vertex position accessor.count = {}", .{ vertex_count });

                while (position_index < vertex_count * 3) : ({
                    position_index += 3;
                    normal_index += 3;
                    uv_index += 2;
                })
                {
                    const position_vector = @Vector(3, f32) { positions.?[position_index], positions.?[position_index + 1], positions.?[position_index + 2], };

                    try model_vertex_positions.append(position_vector);
                    try model_vertices.append(.{
                        .normal = .{ normals.?[normal_index], normals.?[normal_index + 1], normals.?[normal_index + 2] },
                        .uv = .{ texture_coordinates.?[uv_index], texture_coordinates.?[uv_index + 1] }, 
                        .color = packUnorm4x8(.{ 1, 1, 1, 1 }),
                    });

                    bounding_min = @min(bounding_min, position_vector);
                    bounding_max = @max(bounding_max, position_vector);
                }
            }

            std.log.info("bounding_min: {d}", .{ bounding_min });
            std.log.info("bounding_max: {d}", .{ bounding_max });

            //Indices
            {
                const index_accessor = primitive.indices.*;
                const index_buffer_view = index_accessor.buffer_view;
                const index_buffer = index_buffer_view.*.buffer;

                try model_indices.ensureTotalCapacity(model_indices.items.len + index_accessor.count);

                std.log.info("index_accessor.count = {}", .{ index_accessor.count });
                std.log.info("index_accessor.component_type = {}", .{ index_accessor.component_type });

                switch (index_accessor.component_type)
                {
                    cgltf.cgltf_component_type_r_8u => unreachable,
                    cgltf.cgltf_component_type_r_16u => {
                        const indices = @ptrCast([*]u16, 
                            @alignCast(@alignOf(u16), 
                                @ptrCast([*]u8, index_buffer.*.data.?) + index_accessor.offset + index_buffer_view.*.offset))
                                [0..index_accessor.count];                        

                        for (indices) |index|
                        {
                            try model_indices.append(@intCast(u32, index));
                        }
                    },
                    cgltf.cgltf_component_type_r_32u => {
                        const indices = @ptrCast([*]u32, 
                            @alignCast(@alignOf(u32), 
                                @ptrCast([*]u8, index_buffer.*.data.?) + index_accessor.offset + index_buffer_view.*.offset))
                                [0..index_accessor.count];

                        try model_indices.appendSlice(indices);                        
                    },
                    else => unreachable,
                }
            }

            const has_material = primitive.material != null and primitive.material.*.has_pbr_metallic_roughness != 0;

            var material_index: u32 = 0;

            //material
            if (has_material)
            {
                const pbr = primitive.material.*.pbr_metallic_roughness;

                const has_albedo_texture = 
                    pbr.base_color_texture.texture != null and 
                    pbr.base_color_texture.texture.*.image != null and 
                    pbr.base_color_texture.texture.*.image.*.uri != null;

                const has_roughness_texture = 
                    pbr.metallic_roughness_texture.texture != null and
                    pbr.metallic_roughness_texture.texture.*.image != null and 
                    pbr.metallic_roughness_texture.texture.*.image.*.uri != null;

                var albedo_index: ?u32 = null;

                if (has_albedo_texture)
                {
                    for (gltf_images) |*gltf_image, i|
                    {
                        if (gltf_image == pbr.base_color_texture.texture.*.image)
                        {
                            albedo_index = @intCast(u32, i) + 1;

                            break;
                        }
                    }
                }

                var roughness_index: ?u32 = null;

                if (has_roughness_texture)
                {
                    for (gltf_images) |*gltf_image, i|
                    {
                        if (gltf_image == pbr.metallic_roughness_texture.texture.*.image)
                        {
                            roughness_index = @intCast(u32, i) + 1;

                            break;
                        }
                    }
                }

                material_index = @intCast(u32, materials.items.len);

                std.log.info("Material {any}", .{ pbr });

                try materials.append(.{
                    .albedo = pbr.base_color_factor,
                    .albedo_texture_index = albedo_index orelse 0,
                    .roughness = pbr.roughness_factor,
                    .roughness_texture_index = roughness_index orelse 0,
                    .metalness = pbr.metallic_factor,
                    .metalness_texture_index = 0,
                });
            }

            try sub_meshes.append(.{
                .vertex_offset = @intCast(u32, vertex_start),
                .vertex_count = @intCast(u32, model_vertices.items.len - vertex_start),
                .index_offset = @intCast(u32, index_start),
                .index_count = @intCast(u32, model_indices.items.len - index_start),
                .material_index = material_index,
                .transform = transform_matrix,
                .bounding_min = bounding_min,
                .bounding_max = bounding_max,
            });
        }
    }

    std.log.info("unique vertex count: {}", .{ model_vertices.items.len });
    std.log.info("rendered vertex count: {}", .{ model_indices.items.len });

    import_data.vertex_positions = model_vertex_positions.toOwnedSlice();
    import_data.vertices = model_vertices.toOwnedSlice();
    import_data.indices = model_indices.toOwnedSlice();
    import_data.sub_meshes = sub_meshes.toOwnedSlice();
    import_data.materials = materials.toOwnedSlice();
    import_data.textures = textures.toOwnedSlice();
    import_data.point_lights = point_lights.toOwnedSlice(allocator);

    return import_data;
}

pub fn importFree(gltf_import: Import, allocator: std.mem.Allocator) void 
{
    allocator.free(gltf_import.vertex_positions);
    allocator.free(gltf_import.vertices);
    allocator.free(gltf_import.indices);
    allocator.free(gltf_import.sub_meshes);
    allocator.free(gltf_import.materials);
    allocator.free(gltf_import.textures);
    allocator.free(gltf_import.point_lights);
}

///Header for the binary format
pub const ImportBinHeader = packed struct 
{
    vertex_count: u32,
    index_count: u32,
    sub_mesh_count: u32,
    material_count: u32,
    texture_count: u32,
    point_light_count: u32,
};

pub const ImportBinTexture = packed struct 
{
    data_size: u32,
    width: u32,
    height: u32,
};

///Platform specific runtime binary format
///Note that the binary format is not necessarily stable or backwards compatible
///Use runtime imports for modding purposes
pub fn encode(allocator: std.mem.Allocator, import_data: Import) ![]const u8
{
    var size: usize = 0;

    // size = std.mem.alignForward(size, @alignOf(ImportBinHeader));
    size += @sizeOf(ImportBinHeader);    

    size = std.mem.alignForward(size, @alignOf([3]f32));
    size += @sizeOf([3]f32) * import_data.vertex_positions.len;

    size = std.mem.alignForward(size, @alignOf(Renderer3D.Vertex));
    size += @sizeOf(Renderer3D.Vertex) * import_data.vertices.len;
    
    size = std.mem.alignForward(size, @alignOf(u32));
    size += @sizeOf(u32) * import_data.indices.len;

    size = std.mem.alignForward(size, @alignOf(Import.SubMesh));
    size += @sizeOf(Import.SubMesh) * import_data.sub_meshes.len;
    
    size = std.mem.alignForward(size, @alignOf(Import.Material));
    size += @sizeOf(Import.Material) * import_data.materials.len;

    size = std.mem.alignForward(size, @alignOf(ImportBinTexture));
    size += @sizeOf(ImportBinTexture) * import_data.textures.len;

    var texture_data_size: usize = 0;

    for (import_data.textures) |texture|
    {
        texture_data_size += texture.data.len;
    }

    size += texture_data_size;

    size = std.mem.alignForward(size, @alignOf(Renderer3D.PointLight));
    size += @sizeOf(Renderer3D.PointLight) * import_data.point_lights.len;

    const data = try allocator.alloc(u8, size);

    var data_fba = std.heap.FixedBufferAllocator.init(data); 

    const fba = data_fba.allocator();

    const header = try fba.create(ImportBinHeader);

    header.vertex_count = @intCast(u32, import_data.vertices.len);
    header.index_count = @intCast(u32, import_data.indices.len);
    header.sub_mesh_count = @intCast(u32, import_data.sub_meshes.len);
    header.material_count = @intCast(u32, import_data.materials.len);
    header.texture_count = @intCast(u32, import_data.textures.len);
    header.point_light_count = @intCast(u32, import_data.point_lights.len);

    _ = try fba.dupe([3]f32, import_data.vertex_positions);
    _ = try fba.dupe(Renderer3D.Vertex, import_data.vertices);
    _ = try fba.dupe(u32, import_data.indices);
    _ = try fba.dupe(Import.SubMesh, import_data.sub_meshes);
    _ = try fba.dupe(Import.Material, import_data.materials);

    const textures = try fba.alloc(ImportBinTexture, import_data.textures.len);

    for (textures) |*texture, i|
    {
        _ = try fba.dupe(u8, import_data.textures[i].data);

        texture.* = .{
            .data_size = @intCast(u32, import_data.textures[i].data.len),
            .width = import_data.textures[i].width,
            .height = import_data.textures[i].height,
        };
    }

    std.log.info("point_light_offset: {}", .{ data_fba.end_index });

    _ = try fba.dupe(Renderer3D.PointLight, import_data.point_lights);

    return data_fba.buffer[0..data_fba.end_index];
}

///Should probably use a specialized structure for decodes
pub fn decode(allocator: std.mem.Allocator, data: []u8) !Import
{
    var import_data = Import
    {
        .vertex_positions = &.{},
        .vertices = &.{},
        .indices = &.{},
        .sub_meshes = &.{},
        .materials = &.{},
        .textures = &.{},   
        .point_lights = &.{},
    };

    var offset: usize = 0;

    const header = @ptrCast(*const ImportBinHeader, @alignCast(@alignOf(ImportBinHeader), data.ptr + offset));

    std.log.info("header: {}", .{ header });

    offset += @sizeOf(ImportBinHeader);

    const vertex_positions_offset = offset;

    offset = std.mem.alignForward(offset, @alignOf([3]f32));
    offset += @sizeOf([3]f32) * header.vertex_count;

    const vertices_offset = offset;

    offset = std.mem.alignForward(offset, @alignOf(Renderer3D.Vertex));
    offset += @sizeOf(Renderer3D.Vertex) * header.vertex_count;

    const indices_offset = offset;

    offset = std.mem.alignForward(offset, @alignOf(u32));
    offset += @sizeOf(u32) * header.index_count;

    const sub_meshs_offset = offset;

    offset = std.mem.alignForward(offset, @alignOf(Import.SubMesh));
    offset += @sizeOf(Import.SubMesh) * header.sub_mesh_count;

    offset = std.mem.alignForward(offset, @alignOf(Import.Material));
    const materials_offset = offset;

    offset += @sizeOf(Import.Material) * header.material_count;

    offset = std.mem.alignForward(offset, @alignOf(ImportBinTexture));

    const textures_offset = offset;
    offset += @sizeOf(ImportBinTexture) * header.texture_count;

    const texture_data_offset = offset;

    const bin_textures = @ptrCast([*]ImportBinTexture, @alignCast(@alignOf(ImportBinTexture), data.ptr + textures_offset))[0..header.texture_count];

    import_data.textures = try allocator.alloc(Import.Texture, bin_textures.len);
    errdefer allocator.free(import_data.textures);

    {
        var current_texture_data_offset: usize = texture_data_offset;

        for (bin_textures) |bin_texture, i|
        {
            import_data.textures[i] = .{
                .data = (data.ptr + current_texture_data_offset)[0..bin_texture.data_size],
                .width = bin_texture.width,
                .height = bin_texture.height,
            };

            current_texture_data_offset += bin_texture.data_size;
        }

        offset = current_texture_data_offset;
    }

    // offset = std.mem.alignForward(offset, @alignOf(Renderer3D.PointLight));

    const point_light_offset = offset;

    offset += @sizeOf(Renderer3D.PointLight) * header.point_light_count;

    import_data.vertex_positions = @ptrCast([*][3]f32, @alignCast(@alignOf([3]f32), data.ptr + vertex_positions_offset))[0..header.vertex_count];
    import_data.vertices = @ptrCast([*]Renderer3D.Vertex, @alignCast(@alignOf(Renderer3D.Vertex), data.ptr + vertices_offset))[0..header.vertex_count];
    import_data.indices = @ptrCast([*]u32, @alignCast(@alignOf(u32), data.ptr + indices_offset))[0..header.index_count];
    import_data.sub_meshes = @ptrCast([*]Import.SubMesh, @alignCast(@alignOf(Import.SubMesh), data.ptr + sub_meshs_offset))[0..header.sub_mesh_count];
    import_data.materials = @ptrCast([*]Import.Material, @alignCast(@alignOf(Import.Material), data.ptr + materials_offset))[0..header.material_count];
    import_data.point_lights = @ptrCast([*]Renderer3D.PointLight, @alignCast(@alignOf(Renderer3D.PointLight), data.ptr + point_light_offset - 8))[0..header.point_light_count];

    for (import_data.point_lights) |point_light|
    {
        std.log.info("{}", .{ point_light });
    }

    return import_data;
}

pub fn decodeFree(import_data: Import, allocator: std.mem.Allocator) void 
{
    allocator.free(import_data.textures);
}

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