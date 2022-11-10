const ComputePipeline = @This();

const vk = @import("vk.zig");
const Context = @import("Context.zig");

handle: vk.Pipeline,
layout: vk.PipelineLayout,
compute_shader_module: vk.ShaderModule,
descriptor_set_layout: vk.DescriptorSetLayout,

pub fn init(
    shader_code: []align(4) u8,
    size_x: u32,
    size_y: u32,
    size_z: u32,
    comptime PushDataType: ?type,
) !ComputePipeline
{
    _ = shader_code;
    _ = size_x;
    _ = size_y;
    _ = size_z;

    var self = ComputePipeline
    {
        .handle = .null_handle,
        .layout = .null_handle,
        .compute_shader_module = .null_handle,
        .descriptor_set_layout = .null_handle,
    };

    self.layout = try Context.self.vkd.createPipelineLayout(
        Context.self.device, 
        &.{
            .flags = .{},
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast([*]vk.DescriptorSetLayout, &self.descriptor_set_layout),
            .push_constant_range_count = if (PushDataType != null) 1 else 0,
            .p_push_constant_ranges = &[_]vk.PushConstantRange 
            { 
                .{ 
                    .stage_flags = .{
                        .compute_bit = true,
                    },
                    .offset = 0,
                    .size = @sizeOf(PushDataType orelse void),
                },
            },
        }, 
        &Context.self.allocation_callbacks
    );
    errdefer Context.self.vkd.destroyPipelineLayout(Context.self.device, self.layout, &Context.self.allocation_callbacks);

    try Context.self.vkd.createComputePipelines(
        Context.self.device, 
        Context.self.pipeline_cache, 
        1, &[_]vk.ComputePipelineCreateInfo 
        {
            .{
                .flags = .{},
                .stage = vk.PipelineShaderStageCreateInfo
                {
                    .flags = .{},
                    .stage = .{
                        .compute_shader_bit = true,
                    },
                    .module = .null_handle,
                    .p_name = "main",
                    .p_specialization_info = null,
                },
                .layout = self.layout,
                .base_pipeline_handle = .null_handle,
                .base_pipeline_index = 0,
            }
        }, 
        &Context.self.allocation_callbacks,
        @ptrCast([*]vk.Pipeline, &self.handle)
    );
    errdefer Context.self.vkd.destroyPipeline(Context.self.device, self.handle, &Context.self.allocation_callbacks);

    return self;
}

pub fn deinit(self: *ComputePipeline) void
{
    self.* = undefined;

    defer Context.self.vkd.destroyPipelineLayout(Context.self.device, self.layout, &Context.self.allocation_callbacks);
    defer Context.self.vkd.destroyShaderModule(Context.self.device, self.compute_shader_module, &Context.self.allocation_callbacks);
    defer Context.self.vkd.destroyPipeline(Context.self.device, self.handle, &Context.self.allocation_callbacks);
}