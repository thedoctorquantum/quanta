const GraphicsPipeline = @This();

const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");

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

///Provides a compile time known type for fixed function vertex layouts
///Could use the upcoming zig feature inline function parameters with runtime type info
///May also need to user spir-v reflection for more refined automatic vertex layout description 
pub fn init(
    options: Options,
    comptime VertexType: ?type,
    comptime PushDataType: ?type,
    comptime resource_sets: anytype, 
    ) !GraphicsPipeline
{
    _ = resource_sets;

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

    const descriptor_set_layout_bindings = [_]vk.DescriptorSetLayoutBinding
    {
        .{
            .binding = 0,
            .descriptor_type = .storage_buffer,
            .descriptor_count = 1,
            .stage_flags = .{ .vertex_bit = true, },
            .p_immutable_samplers = null,
        },
        // .{
        //     .binding = 1,
        //     .descriptor_type = .combined_image_sampler,
        //     .descriptor_count = 1,
        //     .stage_flags = .{ .fragment_bit = true, },
        //     .p_immutable_samplers = null,
        // },
    };

    const descriptor_pool_sizes = [_]vk.DescriptorPoolSize
    {
        .{
            .@"type" = .storage_buffer,
            .descriptor_count = 1,
        },
        // .{
        //     .@"type" = .combined_image_sampler,
        //     .descriptor_count = 1,
        // },
    };

    const descriptor_set_layout_infos = [1]vk.DescriptorSetLayoutCreateInfo
    {
        .{
            .flags = .{ 
                // .update_after_bind_pool_bit = true, 
                // .push_descriptor_bit_khr = true 
            },
            .binding_count = descriptor_set_layout_bindings.len,
            .p_bindings = &descriptor_set_layout_bindings,
        }
    };

    const Static = struct 
    {
        var descriptor_set_layouts: [descriptor_set_layout_infos.len]vk.DescriptorSetLayout = undefined;
        var descriptor_sets: [descriptor_set_layout_infos.len]vk.DescriptorSet = undefined;
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
        .flags = .{ .update_after_bind_bit = true },
        .max_sets = 1,
        .pool_size_count = 1,
        .p_pool_sizes = &descriptor_pool_sizes,
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
                    .cull_mode = .{},
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