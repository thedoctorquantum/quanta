const GraphicsPipeline = @This();

const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");

handle: vk.Pipeline,
layout: vk.PipelineLayout,
vertex_shader: vk.ShaderModule,
fragment_shader: vk.ShaderModule,

pub const Options = struct 
{
    color_attachment_formats: []const vk.Format,
    depth_attachment_format: ?vk.Format = null,
    stencil_attachment_format: ?vk.Format = null,
    vertex_shader_binary: []align(4) const u8,
    fragment_shader_binary: []align(4) const u8,
};

pub fn init(
    options: Options,
    ) !GraphicsPipeline
{
    var self = GraphicsPipeline
    {
        .handle = .null_handle,
        .layout = .null_handle,
        .vertex_shader = .null_handle,
        .fragment_shader = .null_handle,
    };

    self.layout = try Context.self.vkd.createPipelineLayout(
        Context.self.device, 
        &.{
            .flags = .{},
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
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
        .null_handle, 
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
                    .vertex_binding_description_count = 0,
                    .p_vertex_binding_descriptions = undefined,
                    .vertex_attribute_description_count = 0,
                    .p_vertex_attribute_descriptions = undefined,
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

    defer Context.self.vkd.destroyPipelineLayout(
        Context.self.device, 
        self.layout, 
        &Context.self.allocation_callbacks
    );

    defer Context.self.vkd.destroyShaderModule(Context.self.device, self.vertex_shader, &Context.self.allocation_callbacks);
    defer Context.self.vkd.destroyShaderModule(Context.self.device, self.fragment_shader, &Context.self.allocation_callbacks);

    defer Context.self.vkd.destroyPipeline(
        Context.self.device, 
        self.handle, 
        &Context.self.allocation_callbacks
    );
}