const std = @import("std");
const vk = @import("vk.zig");
const spirv = @import("spirv.zig");

fn getDescriptorType(spirv_op: spirv.SpvOp) vk.DescriptorType
{
    return switch (spirv_op)
    {
        spirv.SpvOpTypeStruct => .storage_buffer,
        spirv.SpvOpTypeImage => .storage_image,
        spirv.SpvOpTypeSampler => .sampler,
        spirv.SpvOpTypeSampledImage => .combined_image_sampler,
        else => unreachable,
    };
}

pub const ShaderParseResult = struct 
{
    resources: [32]Resource = std.mem.zeroes([32]Resource),
    resource_count: u32 = 0,
    resource_mask: u32 = 0,
    local_size_x: u32 = 0,
    local_size_y: u32 = 0,
    local_size_z: u32 = 0,

    const Resource = struct 
    {
        descriptor_type: vk.DescriptorType,
        descriptor_count: u32, 
        binding: u32,
    };
};

pub fn parseShaderModule(result: *ShaderParseResult, allocator: std.mem.Allocator, shader_module_code: []const u32) !void
{
    std.debug.assert(shader_module_code[0] == spirv.SpvMagicNumber);

    const id_count = shader_module_code[3];

    std.log.info("spirv id_count = {}", .{ id_count });

    const Id = struct 
    {
        opcode: u32,
        type_id: u32,
        storage_class: u32,
        binding: u32,
        set: u32,
        constant: u32,
        array_length: u32,
    };

    var ids = try allocator.alloc(Id, id_count);
    defer allocator.free(ids);

    for (ids) |*id|
    {
        id.array_length = 1;
    }

    var local_size_x_id: ?u32 = null;
    var local_size_y_id: ?u32 = null;
    var local_size_z_id: ?u32 = null;

    var word_index: usize = 5;

    while (word_index < shader_module_code.len)
    {
        const word = shader_module_code[word_index];

        const instruction_opcode = @truncate(u16, word);
        const instruction_word_count = @truncate(u16, word >> 16);

        const words = shader_module_code[word_index..word_index + instruction_word_count];

        switch (instruction_opcode)
        {
            spirv.SpvOpEntryPoint => {
                std.log.info("Found shader entry point", .{});
            },
            spirv.SpvOpExecutionMode => {},
            spirv.SpvOpExecutionModeId => {},
            spirv.SpvOpDecorate => {
                const id = words[1];

                std.debug.assert(id < id_count);

                switch (words[2])
                {
                    spirv.SpvDecorationDescriptorSet => {
                        std.log.info("Found descriptor set '{}'", .{ words[3] });

                        ids[id].set = words[3];
                    },
                    spirv.SpvDecorationBinding => {
                        std.log.info("Found descriptor set binding '{}'", .{ words[3] });

                        ids[id].binding = words[3];
                    },
                    else => {},
                }
            },
            spirv.SpvOpTypeStruct,
            spirv.SpvOpTypeImage,
            spirv.SpvOpTypeSampler,
            spirv.SpvOpTypeSampledImage,
            spirv.SpvOpTypeArray,
            spirv.SpvOpTypeRuntimeArray,
            => {
                std.log.info("Found shader descriptor", .{});

                const id = words[1];

                ids[id].opcode = instruction_opcode;

                switch (instruction_opcode)
                {
                    spirv.SpvOpTypeArray => {
                        ids[id].opcode = ids[words[2]].opcode;
                        ids[id].array_length = ids[words[3]].constant;
                    },
                    else => {},
                }
            },
            spirv.SpvOpTypePointer => {
                const id = words[1];

                ids[id].opcode = instruction_opcode;
                ids[id].type_id = words[3];
                ids[id].storage_class = words[2];
            },
            spirv.SpvOpConstant => {
                const id = words[2];

                ids[id].opcode = instruction_opcode;
                ids[id].type_id = words[1];
                ids[id].constant = words[3];

                std.log.info("spirv const = {}", .{ ids[id].constant });
            },
            spirv.SpvOpVariable => {
                const id = words[2];

                ids[id].opcode = instruction_opcode;
                ids[id].type_id = words[1];
                ids[id].storage_class = words[3];
            },
            else => {

            },
        }

        word_index += instruction_word_count;
    }

    for (ids) |id|
    {
        if (id.opcode == spirv.SpvOpVariable and 
            (
                id.storage_class == spirv.SpvStorageClassUniform or 
                id.storage_class == spirv.SpvStorageClassUniformConstant or 
                id.storage_class == spirv.SpvStorageClassStorageBuffer 
            )
        )
        {
            const type_kind = ids[ids[id.type_id].type_id].opcode;
            const array_length = ids[ids[id.type_id].type_id].array_length;
            const resource_type = getDescriptorType(type_kind);

            result.resources[result.resource_count] = .{
                .descriptor_type = resource_type,
                .descriptor_count = array_length,
                .binding = id.binding,
            };

            result.resource_mask |= @as(u32, 1) << @intCast(u5, id.binding);
            result.resource_count += 1;
        }
    }

    if (local_size_x_id != null)
    {
        result.local_size_x = ids[local_size_x_id.?].constant;
    }

    if (local_size_y_id != null)
    {
        result.local_size_y = ids[local_size_y_id.?].constant;
    }

    if (local_size_z_id != null)
    {
        result.local_size_z = ids[local_size_z_id.?].constant;
    }
}
