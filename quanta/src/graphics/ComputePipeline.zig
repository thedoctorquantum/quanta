const ComputePipeline = @This();

const std = @import("std");
const vk = @import("vk.zig");
const spirv_parse = @import("spirv_parse.zig");
const Context = @import("Context.zig");
const Image = @import("Image.zig");
const Sampler = @import("Sampler.zig");
const Buffer = @import("Buffer.zig");

handle: vk.Pipeline,
layout: vk.PipelineLayout,
compute_shader_module: vk.ShaderModule,
descriptor_set_layouts: []vk.DescriptorSetLayout,
descriptor_sets: []vk.DescriptorSet,
descriptor_pool: vk.DescriptorPool,
local_size_x: u32,
local_size_y: u32,
local_size_z: u32,

pub const DispatchType = enum 
{
    @"1d",
    @"2d",
    @"3d",
};

fn closestPowerOfTwo(x: f32) u32
{
    const v = @floatToInt(u32, @round(x));

	var r: u32 = 1;

	while (r * 2 < v)
		r *= 2;

	return r;
} 

pub fn init(
    allocator: std.mem.Allocator,
    shader_code: []align(4) const u8,
    dispatch_type: DispatchType,
    comptime SpecializationDataType: ?type,
    comptime PushDataType: ?type,
) !ComputePipeline
{
    _ = SpecializationDataType;

    var shader_parse_result: spirv_parse.ShaderParseResult = std.mem.zeroes(spirv_parse.ShaderParseResult);

    try spirv_parse.parseShaderModule(&shader_parse_result, allocator, @ptrCast([*]const u32, shader_code.ptr)[0..shader_code.len / @sizeOf(u32)]);

    //This should be close to optimal for most work loads, but not all
    //This isn't a silver bullet, just a very sensible default
    const optimal_local_size: u32 = switch (dispatch_type)
    {
        .@"1d" => Context.self.physical_device_properties.limits.max_compute_work_group_invocations,
        .@"2d" => std.math.sqrt(Context.self.physical_device_properties.limits.max_compute_work_group_invocations),
        .@"3d" => closestPowerOfTwo(std.math.cbrt(@intToFloat(f32, Context.self.physical_device_properties.limits.max_compute_work_group_invocations))),
    };

    var self = ComputePipeline
    {
        .handle = .null_handle,
        .layout = .null_handle,
        .compute_shader_module = .null_handle,
        .descriptor_set_layouts = &.{},
        .descriptor_sets = &.{},
        .descriptor_pool = .null_handle,
        .local_size_x = optimal_local_size,
        .local_size_y = optimal_local_size,
        .local_size_z = optimal_local_size,
    };

    switch (dispatch_type)
    {
        .@"1d" => {
            self.local_size_y = 1;
            self.local_size_z = 1;
        },
        .@"2d" => {
            self.local_size_z = 1;
        },
        .@"3d" => {},
    }

    const descriptor_set_layout_bindings = try allocator.alloc(vk.DescriptorSetLayoutBinding, shader_parse_result.resource_count);
    defer allocator.free(descriptor_set_layout_bindings);

    for (descriptor_set_layout_bindings) |*descriptor_binding, i|
    {
        descriptor_binding.binding = shader_parse_result.resources[i].binding;
        descriptor_binding.descriptor_count = shader_parse_result.resources[i].descriptor_count;
        descriptor_binding.descriptor_type = shader_parse_result.resources[i].descriptor_type;
        descriptor_binding.stage_flags = .{ .compute_bit = true };
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

    self.descriptor_set_layouts = try allocator.alloc(vk.DescriptorSetLayout, descriptor_set_layout_infos.len);
    errdefer allocator.free(self.descriptor_set_layouts);

    self.descriptor_sets = try allocator.alloc(vk.DescriptorSet, self.descriptor_set_layouts.len);
    errdefer allocator.free(self.descriptor_sets);

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

    self.descriptor_pool = try Context.self.vkd.createDescriptorPool(Context.self.device, &.{
        .flags = .{ .update_after_bind_bit = true,  },
        .max_sets = 1,
        .pool_size_count = @intCast(u32, descriptor_pool_sizes.len),
        .p_pool_sizes = descriptor_pool_sizes.ptr,
    }, &Context.self.allocation_callbacks);
    errdefer Context.self.vkd.destroyDescriptorPool(Context.self.device, self.descriptor_pool, &Context.self.allocation_callbacks);

    try Context.self.vkd.allocateDescriptorSets(Context.self.device, &.{
        .descriptor_pool = self.descriptor_pool,
        .descriptor_set_count = @intCast(u32, self.descriptor_set_layouts.len),
        .p_set_layouts = self.descriptor_set_layouts.ptr,
    }, self.descriptor_sets.ptr);

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

    self.compute_shader_module = try Context.self.vkd.createShaderModule(
        Context.self.device, 
        &.{
            .flags = .{},
            .code_size = shader_code.len,
            .p_code = @ptrCast([*]const u32, shader_code.ptr),
        }, 
        &Context.self.allocation_callbacks
    );
    errdefer Context.self.vkd.destroyShaderModule(Context.self.device, self.compute_shader_module, &Context.self.allocation_callbacks);

    _ = try Context.self.vkd.createComputePipelines(
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
                        .compute_bit = true,
                    },
                    .module = self.compute_shader_module,
                    .p_name = shader_parse_result.entry_point.ptr,
                    .p_specialization_info = &.{
                        .map_entry_count = 3,
                        .p_map_entries = &[_]vk.SpecializationMapEntry
                        {
                            .{
                                .constant_id = 0,
                                .offset = 0,
                                .size = @sizeOf(u32),
                            },
                            .{
                                .constant_id = 1,
                                .offset = @sizeOf(u32),
                                .size = @sizeOf(u32),
                            },
                            .{
                                .constant_id = 2,
                                .offset = @sizeOf(u32) * 2,
                                .size = @sizeOf(u32),
                            },
                        },
                        .data_size = @sizeOf(u32) * 3,
                        .p_data = @ptrCast(*const anyopaque, &[_]u32 { self.local_size_x, self.local_size_y, self.local_size_z }),
                    },
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

pub fn deinit(self: *ComputePipeline, allocator: std.mem.Allocator) void
{
    defer self.* = undefined;

    defer Context.self.vkd.destroyPipelineLayout(Context.self.device, self.layout, &Context.self.allocation_callbacks);
    defer Context.self.vkd.destroyDescriptorPool(Context.self.device, self.descriptor_pool, &Context.self.allocation_callbacks);
    defer allocator.free(self.descriptor_set_layouts);
    defer for (self.descriptor_set_layouts) |descriptor_set_layout| 
    {
        Context.self.vkd.destroyDescriptorSetLayout(
            Context.self.device, 
            descriptor_set_layout, 
            &Context.self.allocation_callbacks
        );
    };
    defer allocator.free(self.descriptor_sets);
    defer Context.self.vkd.destroyShaderModule(Context.self.device, self.compute_shader_module, &Context.self.allocation_callbacks);
    defer Context.self.vkd.destroyPipeline(Context.self.device, self.handle, &Context.self.allocation_callbacks);
}

pub fn setDescriptorImage(
    self: *ComputePipeline,    
    index: u32,
    array_index: u32,
    image: Image,
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
                .descriptor_type = .storage_image,
                .p_image_info = &[_]vk.DescriptorImageInfo 
                {
                    .{
                        .sampler = .null_handle,
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

pub fn setDescriptorImageView(
    self: *ComputePipeline,    
    index: u32,
    array_index: u32,
    image_view: Image.View,
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
                .descriptor_type = .storage_image,
                .p_image_info = &[_]vk.DescriptorImageInfo 
                {
                    .{
                        .sampler = .null_handle,
                        .image_view = image_view.handle,
                        .image_layout = .general,
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

pub fn setDescriptorImageSampler(
    self: *ComputePipeline,
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

pub fn setDescriptorImageViewSampler(
    self: *ComputePipeline,
    index: u32,
    array_index: u32,
    image_view: Image.View,
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
                        .image_view = image_view.handle,
                        .image_layout = image_view.image.layout,
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
    self: *ComputePipeline,
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