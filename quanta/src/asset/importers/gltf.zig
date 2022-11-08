const std = @import("std");
const Renderer3D = @import("../../renderer/Renderer3D.zig");
const cgltf = @import("cgltf.zig");
const zalgebra = @import("zalgebra");

pub const Import = struct 
{
    vertices: []Renderer3D.Vertex,
    indices: []u32,
};

pub fn import(allocator: std.mem.Allocator, file_path: []const u8) !Import 
{
    var import_data: Import = undefined;

    var cgltf_data: [*c]cgltf.cgltf_data = null;

    const file_extension = std.fs.path.extension(file_path);
    const file_type = if (std.mem.eql(u8, file_extension, ".gltf")) 
        cgltf.cgltf_file_type_gltf
    else if (std.mem.eql(u8, file_extension, ".glb"))
        cgltf.cgltf_file_type_glb
    else cgltf.cgltf_file_type_gltf;

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

    var model_vertices = std.ArrayList(Renderer3D.Vertex).init(allocator);
    defer model_vertices.deinit();

    var model_indices = std.ArrayList(u32).init(allocator);
    defer model_indices.deinit();

    std.log.info("scene_count: {}", .{ cgltf_data.*.scenes_count });
    std.log.info("node_count: {}", .{ cgltf_data.*.nodes_count });

    std.debug.assert(cgltf_data.*.scene != null);

    const nodes = cgltf_data.*.scene.*.nodes[0..cgltf_data.*.nodes_count];

    for (nodes) |node_ptr|
    {
        if (node_ptr == null) continue;
        if (node_ptr.*.mesh == null) continue;

        var transform_matrix: [4][4]f32 = undefined;

        cgltf.cgltf_node_transform_local(node_ptr, @ptrCast([*]f32, &transform_matrix));

        std.debug.assert(node_ptr != null);
        std.debug.assert(node_ptr.*.mesh != null);

        const node = node_ptr.*;
        const mesh = node.mesh.*;

        std.log.info("node.children_count = {}", .{ node.children_count });
        std.log.info("mesh.primitive_count = {}", .{ mesh.primitives_count });

        for (mesh.primitives[0..mesh.primitives_count]) |primitive|
        {
            const vertex_start = model_vertices.items.len; 
            const index_start = model_indices.items.len;

            _ = vertex_start;
            _ = index_start;

            var vertex_count: usize = 0;
            var positions: ?[]const f32 = null; 
            var normals: ?[]const f32 = null; 
            var texture_coordinates: ?[]const f32 = null; 

            for (primitive.attributes[0..primitive.attributes_count]) |attribute|
            {
                const buffer_view = attribute.data.*.buffer_view;

                if (std.cstr.cmp(attribute.name, "POSITION") == 0)
                {
                    vertex_count = attribute.data.*.count;

                    positions = @ptrCast([*]const f32, @alignCast(@alignOf(f32),
                                    @ptrCast([*]u8, buffer_view.*.buffer.*.data.?) + attribute.data.*.offset + buffer_view.*.offset))
                                    [0..attribute.data.*.count * 3];
                    std.log.info("positions.len = {}", .{ positions.?.len });
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
                    try model_vertices.append(.{
                        .position = .{ positions.?[position_index], positions.?[position_index + 1], positions.?[position_index + 2], },
                        .normal = .{ normals.?[normal_index], normals.?[normal_index + 1], normals.?[normal_index + 2] },
                        .uv = .{ texture_coordinates.?[uv_index], texture_coordinates.?[uv_index + 1] }, 
                        .color = packUnorm4x8(.{ 1, 1, 1, 1 }),
                    });

                    const position = &model_vertices.items[model_vertices.items.len - 1].position;

                    const transformed_position = (zalgebra.Mat4 { .data = transform_matrix }).mulByVec4(.{ .data = .{ position[0], position[1], position[2], 1 } }).data;

                    position.* = .{ transformed_position[0], transformed_position[1], transformed_position[2] };
                }
            }

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

                        for (indices) |index|
                        {
                            try model_indices.append(index);
                        }
                    },
                    else => unreachable,
                }
            }
        }
    }

    std.log.info("unique vertex count: {}", .{ model_vertices.items.len });
    std.log.info("rendered vertex count: {}", .{ model_indices.items.len });

    import_data.vertices = model_vertices.toOwnedSlice();
    import_data.indices = model_indices.toOwnedSlice();

    return import_data;
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