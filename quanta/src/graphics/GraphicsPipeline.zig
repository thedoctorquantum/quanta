const GraphicsPipeline = @This();

const std = @import("std");
const vk = @import("vk.zig");
const spirv = @import("spirv.zig");
const Context = @import("Context.zig");
const Image = @import("Image.zig");
const Sampler = @import("Sampler.zig");
const Buffer = @import("Buffer.zig");

handle: vk.Pipeline,
layout: vk.PipelineLayout,
vertex_shader: vk.ShaderModule,
fragment_shader: vk.ShaderModule,
descriptor_set_layouts: []vk.DescriptorSetLayout,
descriptor_sets: []vk.DescriptorSet,
descriptor_pool: vk.DescriptorPool,

pub const Options = struct 
{
    color_attachment_formats: []const vk.Format,
    depth_attachment_format: ?vk.Format = null,
    stencil_attachment_format: ?vk.Format = null,
    vertex_shader_binary: []align(4) const u8,
    fragment_shader_binary: []align(4) const u8,
    vertex_attribute_descriptions: []const vk.VertexInputAttributeDescription = &.{},
};

fn getAttributeFormat(comptime T: type) vk.Format 
{
    switch (@typeInfo(T))
    {
        .Int => |int| {
            return switch (int.bits)
            {
                32 => if (int.signedness == .unsigned) .r32_uint else .r32_sint,
                64 => if (int.signedness == .unsigned) .r64_uint else .r64_sint,
                else => comptime unreachable,
            };
        },
        .Float => |float| 
        {
            return switch (float.bits)
            {
                32 => .r32_sfloat,
                64 => .r64_sfloat,
                else => comptime unreachable,
            };
        },
        .Array => |array| block: {
            switch (@typeInfo(array.child))
            {
                .Float => |float| {
                    switch (float.bits)
                    {
                        32 => {
                            return switch (array.len)
                            {
                                2 => .r32g32_sfloat,
                                3 => .r32g32b32_sfloat,
                                4 => .r32g32b32a32_sfloat,
                                else => comptime unreachable,
                            };
                        },
                        64 => {
                            return switch (array.len)
                            {
                                2 => .r64g64_sfloat,
                                3 => .r64g64b64_sfloat,
                                4 => .r64g64b64a64_sfloat,
                                else => comptime unreachable,
                            };
                        },
                        else => comptime unreachable,
                    }
                },
                else => comptime unreachable,
            }

            break: block 0;
        },
        else => comptime unreachable,
    }

    comptime unreachable;
}

///Crude comptime attribute generator from type information, which isn't really sufficient 
///but will do the job in most cases 
///Also assumes interleaved memory layout
fn getVertexLayout(comptime T: type) [if (T == void) 0 else std.meta.fieldNames(T).len]vk.VertexInputAttributeDescription
{
    if (T == void) return [_]vk.VertexInputAttributeDescription {};

    std.debug.assert(std.meta.containerLayout(T) == .Extern);

    var attributes: [std.meta.fieldNames(T).len]vk.VertexInputAttributeDescription = undefined;

    inline for (std.meta.fields(T)) |field, i|
    {
        const format = getAttributeFormat(field.field_type);

        attributes[i] = .{
            .binding = 0,
            .location = i,
            .format = format,
            .offset = @offsetOf(T, field.name),
        };
    }

    return attributes;
}

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

const ShaderParseResult = struct 
{
    resource_types: [32]vk.DescriptorType,
    resource_array_lengths: [32]u32,
    resource_count: u32,
    resource_mask: u32,
};

fn parseShaderModule(result: *ShaderParseResult, allocator: std.mem.Allocator, shader_module_code: []const u32) !void
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
            else => {},
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

            result.resource_array_lengths[id.binding] = array_length;

            result.resource_types[id.binding] = resource_type;
            result.resource_mask |= @as(u32, 1) << @intCast(u5, id.binding);
            result.resource_count += 1;
        }
    }
}

///Provides a compile time known type for fixed function vertex layouts
///Could use the upcoming zig feature inline function parameters with runtime type info
///May also need to user spir-v reflection for more refined automatic vertex layout description 
pub fn init(
    allocator: std.mem.Allocator,
    options: Options,
    comptime VertexType: ?type,
    comptime PushDataType: ?type,
    comptime resource_sets: anytype, 
    ) !GraphicsPipeline
{
    _ = resource_sets;


    var shader_parse_result: ShaderParseResult = .{
        .resource_types = [_]vk.DescriptorType { @intToEnum(vk.DescriptorType, @as(i32, std.math.maxInt(i32))) } ** 32,
        .resource_array_lengths = [_]u32 { 1 } ** 32,
        .resource_count = 0,
        .resource_mask = 0,
    };

    try parseShaderModule(&shader_parse_result, allocator, @ptrCast([*]const u32, options.vertex_shader_binary.ptr)[0..options.vertex_shader_binary.len / 4]);
    try parseShaderModule(&shader_parse_result, allocator, @ptrCast([*]const u32, options.fragment_shader_binary.ptr)[0..options.fragment_shader_binary.len / 4]);

    for (shader_parse_result.resource_types[0..shader_parse_result.resource_count]) |resource_type, i|
    {
        std.log.info("resources[{}] = {}, count = {}", .{ i, resource_type, shader_parse_result.resource_array_lengths[i] });
    }

    const vertex_binding_descriptions = [_]vk.VertexInputBindingDescription 
    {
        .{ 
            .binding = 0,
            .stride = if (VertexType != null) @sizeOf(VertexType.?) else 0,
            .input_rate = .vertex,
        }, 
    };

    const vertex_attribute_descriptions = getVertexLayout(VertexType orelse void);

    if (VertexType != null)
    {
        std.log.debug("Vertex format for {s}: {any}", .{ @typeName(VertexType.?), vertex_attribute_descriptions });
    }

    const descriptor_set_layout_bindings = try allocator.alloc(vk.DescriptorSetLayoutBinding, shader_parse_result.resource_count);
    defer allocator.free(descriptor_set_layout_bindings);

    for (descriptor_set_layout_bindings) |*descriptor_binding, i|
    {
        descriptor_binding.binding = @intCast(u32, i);
        descriptor_binding.descriptor_count = shader_parse_result.resource_array_lengths[i];
        descriptor_binding.descriptor_type = shader_parse_result.resource_types[i];
        descriptor_binding.stage_flags = .{ .vertex_bit = true, .fragment_bit = true, };
        descriptor_binding.p_immutable_samplers = null;
    }

    const descriptor_set_layout_binding_flags = try allocator.alloc(vk.DescriptorBindingFlags, shader_parse_result.resource_count);
    defer allocator.free(descriptor_set_layout_binding_flags);

    for (descriptor_set_layout_binding_flags) |*binding_flags|
    {
        binding_flags.* = .{ .update_after_bind_bit = true, .partially_bound_bit = true, .update_unused_while_pending_bit = true, };
    }

    const descriptor_pool_sizes = try allocator.alloc(vk.DescriptorPoolSize, shader_parse_result.resource_count);
    defer allocator.free(descriptor_pool_sizes);

    for (descriptor_pool_sizes) |*descriptor_pool_size, i|
    {
        descriptor_pool_size.* = .{
            .@"type" = shader_parse_result.resource_types[i],
            .descriptor_count = shader_parse_result.resource_array_lengths[i],
        };
    }

    const descriptor_set_layout_infos = [1]vk.DescriptorSetLayoutCreateInfo
    {
        .{
            .p_next = &vk.DescriptorSetLayoutBindingFlagsCreateInfo
            {
                .binding_count = @intCast(u32, descriptor_set_layout_binding_flags.len),
                .p_binding_flags = descriptor_set_layout_binding_flags.ptr,
            },
            .flags = .{ .update_after_bind_pool_bit = true, },
            .binding_count = @intCast(u32, descriptor_set_layout_bindings.len),
            .p_bindings = descriptor_set_layout_bindings.ptr,
        }
    };

    const Static = struct 
    {
        var descriptor_set_layouts: [1]vk.DescriptorSetLayout = undefined;
        var descriptor_sets: [1]vk.DescriptorSet = undefined;
    };

    var self = GraphicsPipeline
    {
        .handle = .null_handle,
        .layout = .null_handle,
        .vertex_shader = .null_handle,
        .fragment_shader = .null_handle,
        .descriptor_set_layouts = &Static.descriptor_set_layouts,
        .descriptor_sets = &Static.descriptor_sets,
        .descriptor_pool = .null_handle,
    };

    self.descriptor_pool = try Context.self.vkd.createDescriptorPool(Context.self.device, &.{
        .flags = .{ .update_after_bind_bit = true,  },
        .max_sets = 1,
        .pool_size_count = @intCast(u32, descriptor_pool_sizes.len),
        .p_pool_sizes = descriptor_pool_sizes.ptr,
    }, &Context.self.allocation_callbacks);
    errdefer Context.self.vkd.destroyDescriptorPool(Context.self.device, self.descriptor_pool, &Context.self.allocation_callbacks);

    for (Static.descriptor_set_layouts) |*descriptor_set_layout, i|
    {
        descriptor_set_layout.* = try Context.self.vkd.createDescriptorSetLayout(
            Context.self.device,
            &descriptor_set_layout_infos[i],
            &Context.self.allocation_callbacks
        );
    }

    errdefer for (Static.descriptor_set_layouts) |descriptor_set_layout|
    {
        Context.self.vkd.destroyDescriptorSetLayout(Context.self.device, descriptor_set_layout, &Context.self.allocation_callbacks);
    };

    try Context.self.vkd.allocateDescriptorSets(Context.self.device, &.{
        .descriptor_pool = self.descriptor_pool,
        .descriptor_set_count = Static.descriptor_set_layouts.len,
        .p_set_layouts = &Static.descriptor_set_layouts,
    }, &Static.descriptor_sets);
    errdefer Context.self.vkd.freeDescriptorSets(Context.self.device, self.descriptor_pool, Static.descriptor_sets.len, &Static.descriptor_sets) catch unreachable;

    self.layout = try Context.self.vkd.createPipelineLayout(
        Context.self.device, 
        &.{
            .flags = .{},
            .set_layout_count = @intCast(u32, self.descriptor_set_layouts.len),
            .p_set_layouts = self.descriptor_set_layouts.ptr,
            .push_constant_range_count = if (PushDataType != null) 1 else 0,
            .p_push_constant_ranges = &[_]vk.PushConstantRange 
            { 
                .{ 
                    .stage_flags = .{
                        .vertex_bit = true,
                        .fragment_bit = true,
                    },
                    .offset = 0,
                    .size = @sizeOf(PushDataType orelse void),
                },
            },
        }, 
        &Context.self.allocation_callbacks
    );
    errdefer Context.self.vkd.destroyPipelineLayout(Context.self.device, self.layout, &Context.self.allocation_callbacks);

    const shader_entry_point = "main";

    self.vertex_shader = try Context.self.vkd.createShaderModule(
        Context.self.device, 
        &.{
            .flags = .{},
            .code_size = options.vertex_shader_binary.len,
            .p_code = @ptrCast([*]const u32, options.vertex_shader_binary.ptr),
        }, 
        &Context.self.allocation_callbacks
    );
    errdefer Context.self.vkd.destroyShaderModule(Context.self.device, self.vertex_shader, &Context.self.allocation_callbacks);

    self.fragment_shader = try Context.self.vkd.createShaderModule(
        Context.self.device, 
        &.{
            .flags = .{},
            .code_size = options.fragment_shader_binary.len,
            .p_code = @ptrCast([*]const u32, options.fragment_shader_binary.ptr),
        }, 
        &Context.self.allocation_callbacks
    );
    errdefer Context.self.vkd.destroyShaderModule(Context.self.device, self.fragment_shader, &Context.self.allocation_callbacks);

    const shader_stage_infos = [_]vk.PipelineShaderStageCreateInfo 
    {
        .{
            .flags = .{},
            .stage = .{ .vertex_bit = true },
            .module = self.vertex_shader,
            .p_name = shader_entry_point,
            .p_specialization_info = &.{
                .map_entry_count = 0,
                .p_map_entries = undefined,
                .data_size = 0,
                .p_data = undefined,
            },
        }, 
        .{
            .flags = .{},
            .stage = .{ .fragment_bit = true },
            .module = self.fragment_shader,
            .p_name = shader_entry_point,
            .p_specialization_info = &.{
                .map_entry_count = 0,
                .p_map_entries = undefined,
                .data_size = 0,
                .p_data = undefined,
            },
        },
    };

    const dynamic_states = [_]vk.DynamicState
    {
        .viewport,
        .scissor,
    };

    _ = try Context.self.vkd.createGraphicsPipelines(
        Context.self.device, 
        Context.self.pipeline_cache, 
        1, 
        &[_]vk.GraphicsPipelineCreateInfo {
            .{
                .p_next = &vk.PipelineRenderingCreateInfo
                {
                    .view_mask = 0,
                    .color_attachment_count = @intCast(u32, options.color_attachment_formats.len),
                    .p_color_attachment_formats = options.color_attachment_formats.ptr,
                    .depth_attachment_format = options.depth_attachment_format orelse .@"undefined",
                    .stencil_attachment_format = options.stencil_attachment_format orelse .@"undefined",
                },
                .flags = .{},
                .stage_count = shader_stage_infos.len,
                .p_stages = &shader_stage_infos,
                .p_vertex_input_state = &.{
                    .flags = .{},
                    .vertex_binding_description_count = if (VertexType != null) @intCast(u32, vertex_binding_descriptions.len) else 0,
                    .p_vertex_binding_descriptions = &vertex_binding_descriptions,
                    .vertex_attribute_description_count = if (VertexType != null) @intCast(u32, vertex_attribute_descriptions.len) else 0,
                    .p_vertex_attribute_descriptions = &vertex_attribute_descriptions,
                },
                .p_input_assembly_state = &.{
                    .flags = .{},
                    .topology = .triangle_list,
                    .primitive_restart_enable = vk.FALSE,  
                },
                .p_tessellation_state = null,
                .p_viewport_state = &.{
                    .flags = .{},
                    .viewport_count = 1,
                    .p_viewports = null,
                    .scissor_count = 1,
                    .p_scissors = null,
                },
                .p_rasterization_state = &.{
                    .flags = .{},
                    .depth_clamp_enable = vk.FALSE,
                    .rasterizer_discard_enable = vk.FALSE,
                    .polygon_mode = .fill,
                    .line_width = 1,
                    .cull_mode = .{ .back_bit = true, },
                    .front_face = .clockwise,
                    .depth_bias_enable = vk.FALSE,
                    .depth_bias_constant_factor = 0,
                    .depth_bias_clamp = 0,
                    .depth_bias_slope_factor = 0,  
                },
                .p_multisample_state = &.{
                    .flags = .{},
                    .sample_shading_enable = vk.FALSE,
                    .rasterization_samples = .{ .@"1_bit" = true },
                    .min_sample_shading = 1,
                    .p_sample_mask = null,
                    .alpha_to_coverage_enable = vk.FALSE,
                    .alpha_to_one_enable = vk.FALSE,
                },
                .p_depth_stencil_state = &.{
                    .flags = .{},
                    .depth_test_enable = vk.TRUE,
                    .depth_write_enable = vk.TRUE,
                    .depth_compare_op = .less_or_equal,
                    .depth_bounds_test_enable = vk.FALSE,
                    .stencil_test_enable = vk.FALSE,
                    .front = std.mem.zeroes(vk.StencilOpState),
                    .back = std.mem.zeroes(vk.StencilOpState),
                    .min_depth_bounds = 0,
                    .max_depth_bounds = 1,
                },
                .p_color_blend_state = &.{
                    .flags = .{},
                    .logic_op_enable = vk.FALSE,
                    .logic_op = .copy,
                    .attachment_count = 1,
                    .p_attachments = &[_]vk.PipelineColorBlendAttachmentState {.{
                        .color_write_mask =.{
                            .r_bit = true,
                            .g_bit = true,
                            .b_bit = true,
                            .a_bit = true,   
                        },
                        .blend_enable = vk.TRUE,
                        .src_color_blend_factor = .one,
                        .dst_color_blend_factor = .zero,
                        .color_blend_op = .add,
                        .src_alpha_blend_factor = .one,
                        .dst_alpha_blend_factor = .zero,
                        .alpha_blend_op = .add,
                    }},
                    .blend_constants = .{ 0, 0, 0, 0 },
                },
                .p_dynamic_state = &.{
                    .flags = .{},
                    .dynamic_state_count = dynamic_states.len,
                    .p_dynamic_states = &dynamic_states,
                },
                .layout = self.layout,
                .render_pass = .null_handle,
                .subpass = 0,
                .base_pipeline_handle = .null_handle,
                .base_pipeline_index = 0,
            }
        }, 
        &Context.self.allocation_callbacks, 
        @ptrCast([*]vk.Pipeline, &self.handle)
    );

    return self;
}

pub fn deinit(self: *GraphicsPipeline) void 
{
    defer self.* = undefined;

    defer Context.self.vkd.destroyDescriptorPool(Context.self.device, self.descriptor_pool, &Context.self.allocation_callbacks);
    defer Context.self.vkd.destroyPipelineLayout(
        Context.self.device, 
        self.layout, 
        &Context.self.allocation_callbacks
    );

    defer for (self.descriptor_set_layouts) |descriptor_set_layout|
    {
        Context.self.vkd.destroyDescriptorSetLayout(Context.self.device, descriptor_set_layout, &Context.self.allocation_callbacks);
    };

    defer Context.self.vkd.destroyShaderModule(Context.self.device, self.vertex_shader, &Context.self.allocation_callbacks);
    defer Context.self.vkd.destroyShaderModule(Context.self.device, self.fragment_shader, &Context.self.allocation_callbacks);

    defer Context.self.vkd.destroyPipeline(
        Context.self.device, 
        self.handle, 
        &Context.self.allocation_callbacks
    );
}

pub fn setDescriptorImageSampler(
    self: *GraphicsPipeline,
    index: u32,
    array_index: u32,
    image: Image,
    sampler: Sampler,
) void 
{
    Context.self.vkd.updateDescriptorSets(
        Context.self.device, 
        1, 
        &[_]vk.WriteDescriptorSet
        {
            .{
                .dst_set = self.descriptor_sets[0],
                .dst_binding = index,
                .dst_array_element = array_index,
                .descriptor_count = 1,
                .descriptor_type = .combined_image_sampler,
                .p_image_info = &[_]vk.DescriptorImageInfo 
                {
                    .{
                        .sampler = sampler.handle,
                        .image_view = image.view,
                        .image_layout = image.layout,
                    }
                },
                .p_buffer_info = undefined,
                .p_texel_buffer_view = undefined,
            },
        }, 
        0, 
        undefined,
    );
}

pub fn setDescriptorBuffer(
    self: *GraphicsPipeline,
    index: u32,
    array_index: u32,
    buffer: Buffer,
) void
{
    const descriptor_type: vk.DescriptorType = switch (buffer.usage)
    {
        .vertex => .storage_buffer,
        .index => .storage_buffer,
        .uniform => .uniform_buffer,
        .storage => .storage_buffer,
        .indirect_draw => .storage_buffer,
        .staging => unreachable,
    };

    Context.self.vkd.updateDescriptorSets(
        Context.self.device, 
        1, 
        &[_]vk.WriteDescriptorSet
        {
            .{
                .dst_set = self.descriptor_sets[0],
                .dst_binding = index,
                .dst_array_element = array_index,
                .descriptor_count = 1,
                .descriptor_type = descriptor_type,
                .p_image_info = undefined,
                .p_buffer_info = &[_]vk.DescriptorBufferInfo 
                {
                    .{
                        .buffer = buffer.handle,
                        .offset = 0,
                        .range = buffer.size,
                    }
                },
                .p_texel_buffer_view = undefined,
            },
        }, 
        0, 
        undefined,
    );
}