const GraphicsPipeline = @This();

const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");
const Image = @import("Image.zig");
const Sampler = @import("Sampler.zig");
const Buffer = @import("Buffer.zig");
const spirv_parse = @import("spirv_parse.zig");

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
    depth_state: DepthState = .{},
    rasterisation_state: RasterisationState = .{},
    blend_state: BlendState = .{},

    pub const DepthState = struct 
    {
        write_enabled: bool = false,
        test_enabled: bool = false,
        compare_op: CompareOp = .greater,

        pub const CompareOp = enum 
        {
            less,
            less_or_equal,
            greater,
            greater_or_equal,
            always,
        };
    };

    pub const RasterisationState = struct 
    {
        polygon_mode: PolygonMode = .fill,
        cull_mode: CullMode = .none,
        vertex_winding: VertexWinding = .counter_clockwise,

        pub const PolygonMode = enum 
        {
            fill,
            line,
        };

        pub const CullMode = enum 
        {
            none,
            back,
            front,
        };

        pub const VertexWinding = enum 
        {
            clockwise,
            counter_clockwise,
        };
    };

    pub const BlendState = struct 
    {
        blend_enabled: bool = false,
        src_alpha: BlendFactor = .one,
        dst_alpha: BlendFactor = .zero,
        alpha_blend_op: BlendOp = .add,
        src_color: BlendFactor = .src_alpha,
        dst_color: BlendFactor = .one_minus_src_alpha,
        color_blend_op: BlendOp = .add,

        pub const BlendFactor = enum
        {
            zero,
            one,
            src_color,
            one_minus_src_color,
            dst_color,
            one_minus_dst_color,
            src_alpha,
            one_minus_src_alpha,
            dst_alpha,
            one_minus_dst_alpha,
            constant_color,
            one_minus_constant_color,
            constant_alpha,
            one_minus_constant_alpha,
            src_alpha_saturate,
            src1_color,
            one_minus_src1_color,
            src1_alpha,
            one_minus_src1_alpha,
        };

        pub const BlendOp = enum 
        {
            add,
            subtract,
            reverse_subtract,
            min,
            max,
        };
    };
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

///Provides a compile time known type for fixed function vertex layouts
///Could use the upcoming zig feature inline function parameters with runtime type info
pub fn init(
    allocator: std.mem.Allocator,
    options: Options,
    comptime VertexType: ?type,
    comptime PushDataType: ?type,
    ) !GraphicsPipeline
{
    if (@sizeOf(PushDataType orelse void) > 128)
    {
        @compileLog("PushData cannot be larger than 128 bytes");
    }

    var shader_parse_result: spirv_parse.ShaderParseResult = std.mem.zeroes(spirv_parse.ShaderParseResult);

    try spirv_parse.parseShaderModule(&shader_parse_result, allocator, @ptrCast([*]const u32, options.vertex_shader_binary.ptr)[0..options.vertex_shader_binary.len / @sizeOf(u32)]);

    const vertex_shader_entry_point = shader_parse_result.entry_point;

    try spirv_parse.parseShaderModule(&shader_parse_result, allocator, @ptrCast([*]const u32, options.fragment_shader_binary.ptr)[0..options.fragment_shader_binary.len / @sizeOf(u32)]);

    const fragment_shader_entry_point = shader_parse_result.entry_point;

    const vertex_binding_descriptions = [_]vk.VertexInputBindingDescription 
    {
        .{ 
            .binding = 0,
            .stride = if (VertexType != null) @sizeOf(VertexType.?) else 0,
            .input_rate = .vertex,
        }, 
    };

    const vertex_attribute_descriptions = getVertexLayout(VertexType orelse void);

    const descriptor_set_layout_bindings = try allocator.alloc(vk.DescriptorSetLayoutBinding, shader_parse_result.resource_count);
    defer allocator.free(descriptor_set_layout_bindings);

    for (descriptor_set_layout_bindings) |*descriptor_binding, i|
    {
        descriptor_binding.binding = shader_parse_result.resources[i].binding;
        descriptor_binding.descriptor_count = shader_parse_result.resources[i].descriptor_count;
        descriptor_binding.descriptor_type = shader_parse_result.resources[i].descriptor_type;
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
            .@"type" = shader_parse_result.resources[i].descriptor_type,
            .descriptor_count = shader_parse_result.resources[i].descriptor_count,
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

    var self = GraphicsPipeline
    {
        .handle = .null_handle,
        .layout = .null_handle,
        .vertex_shader = .null_handle,
        .fragment_shader = .null_handle,
        .descriptor_set_layouts = &.{},
        .descriptor_sets = &.{},
        .descriptor_pool = .null_handle,
    };

    self.descriptor_set_layouts = try allocator.alloc(vk.DescriptorSetLayout, 1);
    errdefer allocator.free(self.descriptor_set_layouts);

    self.descriptor_sets = try allocator.alloc(vk.DescriptorSet, 1);
    errdefer allocator.free(self.descriptor_sets);

    self.descriptor_pool = try Context.self.vkd.createDescriptorPool(Context.self.device, &.{
        .flags = .{ .update_after_bind_bit = true,  },
        .max_sets = 1,
        .pool_size_count = @intCast(u32, descriptor_pool_sizes.len),
        .p_pool_sizes = descriptor_pool_sizes.ptr,
    }, &Context.self.allocation_callbacks);
    errdefer Context.self.vkd.destroyDescriptorPool(Context.self.device, self.descriptor_pool, &Context.self.allocation_callbacks);

    for (self.descriptor_set_layouts) |*descriptor_set_layout, i|
    {
        descriptor_set_layout.* = try Context.self.vkd.createDescriptorSetLayout(
            Context.self.device,
            &descriptor_set_layout_infos[i],
            &Context.self.allocation_callbacks
        );
    }

    errdefer for (self.descriptor_set_layouts) |descriptor_set_layout|
    {
        Context.self.vkd.destroyDescriptorSetLayout(Context.self.device, descriptor_set_layout, &Context.self.allocation_callbacks);
    };

    try Context.self.vkd.allocateDescriptorSets(Context.self.device, &.{
        .descriptor_pool = self.descriptor_pool,
        .descriptor_set_count = @intCast(u32, self.descriptor_set_layouts.len),
        .p_set_layouts = self.descriptor_set_layouts.ptr,
    }, self.descriptor_sets.ptr);
    errdefer Context.self.vkd.freeDescriptorSets(Context.self.device, self.descriptor_pool, @intCast(u32, self.descriptor_sets.len), self.descriptor_sets.ptr) catch unreachable;

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
            .p_name = vertex_shader_entry_point.ptr,
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
            .p_name = fragment_shader_entry_point.ptr,
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
                    .polygon_mode = switch (options.rasterisation_state.polygon_mode)
                    {
                        .fill => vk.PolygonMode.fill,
                        .line => vk.PolygonMode.line,
                    },
                    .line_width = 1,
                    .cull_mode = switch (options.rasterisation_state.cull_mode)
                    {
                        .none => vk.CullModeFlags {},
                        .back => vk.CullModeFlags { .back_bit = true, },
                        .front => vk.CullModeFlags { .front_bit = true, },
                    },
                    .front_face = switch (options.rasterisation_state.vertex_winding)
                    {
                        .clockwise => vk.FrontFace.clockwise,
                        .counter_clockwise => vk.FrontFace.counter_clockwise,
                    },
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
                    .depth_test_enable = @boolToInt(options.depth_state.test_enabled),
                    .depth_write_enable = @boolToInt(options.depth_state.write_enabled),
                    .depth_compare_op = @as(vk.CompareOp, switch (options.depth_state.compare_op)
                    {
                        .less => .less,
                        .less_or_equal => .less_or_equal,
                        .greater => .greater,
                        .greater_or_equal => .greater_or_equal,
                        .always => .always,
                    }),
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
                        .color_write_mask = .{
                            .r_bit = true,
                            .g_bit = true,
                            .b_bit = true,
                            .a_bit = true,   
                        },
                        .blend_enable = @boolToInt(options.blend_state.blend_enabled),
                        .src_color_blend_factor = .src_alpha,
                        .dst_color_blend_factor = .one_minus_src_alpha,
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

pub fn deinit(self: *GraphicsPipeline, allocator: std.mem.Allocator) void 
{
    defer self.* = undefined;

    defer Context.self.vkd.destroyDescriptorPool(Context.self.device, self.descriptor_pool, &Context.self.allocation_callbacks);
    defer Context.self.vkd.destroyPipelineLayout(
        Context.self.device, 
        self.layout, 
        &Context.self.allocation_callbacks
    );

    defer allocator.free(self.descriptor_set_layouts);
    defer allocator.free(self.descriptor_sets);
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
        .indirect => .storage_buffer,
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