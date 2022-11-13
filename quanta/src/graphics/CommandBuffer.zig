const CommandBuffer = @This();

const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");
const ComputePipeline = @import("ComputePipeline.zig");
const GraphicsPipeline = @import("GraphicsPipeline.zig");
const Buffer = @import("Buffer.zig");
const Image = @import("Image.zig");
const Fence = @import("Fence.zig");

pub const Queue = enum 
{
    graphics,
    compute,
};

handle: vk.CommandBuffer,
queue: Queue,
pipeline_layout: vk.PipelineLayout,
wait_fence: Fence, 
local_size_x: u32,
local_size_y: u32,
local_size_z: u32,
is_graphics_pipeline: bool,

pub fn init(queue: Queue) !CommandBuffer
{
    var self: CommandBuffer = .{
        .handle = .null_handle,
        .queue = queue,
        .pipeline_layout = .null_handle,
        .wait_fence = undefined,
        .local_size_x = 0,
        .local_size_y = 0,
        .local_size_z = 0,
        .is_graphics_pipeline = false,
    };

    self.wait_fence = try Fence.init();
    errdefer self.wait_fence.deinit();

    const pool = switch (self.queue)
    {
        .graphics => Context.self.graphics_command_pool,
        .compute => Context.self.compute_command_pool,  
    };

    try Context.self.vkd.allocateCommandBuffers(Context.self.device, &.{
        .command_pool = pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, @ptrCast([*]vk.CommandBuffer, &self.handle));

    return self;
}

pub fn deinit(self: *CommandBuffer) void
{
    defer self.* = undefined;

    const pool = switch (self.queue)
    {
        .graphics => Context.self.graphics_command_pool,
        .compute => Context.self.compute_command_pool,  
    };

    defer self.wait_fence.deinit();
    defer Context.self.vkd.freeCommandBuffers(Context.self.device, pool, 1, @ptrCast([*]vk.CommandBuffer, &self.handle));
}

pub fn begin(self: CommandBuffer) !void 
{
    try Context.self.vkd.resetCommandBuffer(self.handle, .{});
    try Context.self.vkd.beginCommandBuffer(self.handle, &.{
        .flags = .{
            .one_time_submit_bit = true,
        },
        .p_inheritance_info = null,
    });
}

pub fn end(self: CommandBuffer) void 
{
    Context.self.vkd.endCommandBuffer(self.handle) catch unreachable;
}

pub fn submitAndWait(self: CommandBuffer) !void 
{
    try self.submit(self.wait_fence);
    self.wait_fence.wait();
    self.wait_fence.reset();
}

pub fn submit(self: CommandBuffer, fence: Fence) !void 
{
    try Context.self.vkd.queueSubmit2(Context.self.graphics_queue, 1, &[_]vk.SubmitInfo2
    {
        .{
            .flags = .{},
            .wait_semaphore_info_count = 0,
            .p_wait_semaphore_infos = undefined,
            .command_buffer_info_count = 1,
            .p_command_buffer_infos = &[_]vk.CommandBufferSubmitInfo {
                .{
                    .command_buffer = self.handle,
                    .device_mask = 0,
                }
            },
            .signal_semaphore_info_count = 0,
            .p_signal_semaphore_infos = undefined,
        }
    }, fence.handle);
}

pub const Attachment = struct 
{
    image: *const Image,
    clear: ?Clear,

    pub const Clear = union(enum)
    {
        color: [4]f32,
        depth: f32,
    };
};

pub fn beginRenderPass(
    self: CommandBuffer, 
    offset_x: i32,
    offset_y: i32,
    width: u32,
    height: u32,
    color_attachments: []Attachment, 
    depth_attachment: ?Attachment
) void 
{
    var color_attachment_infos: [8]vk.RenderingAttachmentInfo = undefined;

    for (color_attachments) |color_attachment, i|
    {
        color_attachment_infos[i] = .{
            .image_view = color_attachment.image.view,
            .image_layout = .attachment_optimal,
            .resolve_mode = .{},
            .resolve_image_view = .null_handle,
            .resolve_image_layout = .@"undefined",
            .load_op = if (color_attachment.clear != null) .clear else .load,
            .store_op = .store,
            .clear_value = if (color_attachment.clear != null) switch (color_attachment.clear.?)
            {
                .color => .{ .color = .{ .float_32 = color_attachment.clear.?.color } },
                .depth => .{ .depth_stencil = .{ .depth = color_attachment.clear.?.depth, .stencil = 1, } },
            } else .{ .color = .{ .float_32 = .{ 0, 0, 0, 0 } } },
        };
    }

    var depth_attachment_info: vk.RenderingAttachmentInfo = undefined;

    if (depth_attachment != null)
    {
        depth_attachment_info = .{
            .image_view = depth_attachment.?.image.view,
            .image_layout = .attachment_optimal,
            .resolve_mode = .{},
            .resolve_image_view = .null_handle,
            .resolve_image_layout = .@"undefined",
            .load_op = if (depth_attachment.?.clear != null) .clear else .load,
            .store_op = .store, //May want to set this to dont_care to let the driver optimise 
            .clear_value = if (depth_attachment.?.clear != null) switch (depth_attachment.?.clear.?)
            {
                .color => .{ .color = .{ .float_32 = depth_attachment.?.clear.?.color } },
                .depth => .{ .depth_stencil = .{ .depth = depth_attachment.?.clear.?.depth, .stencil = 1, } },
            } else .{ .color = .{ .float_32 = .{ 0, 0, 0, 0 } } },
        };
    }

    Context.self.vkd.cmdBeginRendering(self.handle, &.{
        .flags = .{},
        .render_area = .{ 
            .offset = .{ .x = offset_x, .y = offset_y }, 
            .extent = .{ .width = width, .height = height } 
        },
        .layer_count = 1,
        .view_mask = 0,
        .color_attachment_count = @intCast(u32, color_attachments.len),
        .p_color_attachments = &color_attachment_infos,
        .p_depth_attachment = if (depth_attachment != null) &depth_attachment_info else null,
        .p_stencil_attachment = null,
    });
}

pub fn endRenderPass(self: CommandBuffer) void 
{
    Context.self.vkd.cmdEndRendering(self.handle);
}

pub fn setGraphicsPipeline(self: *CommandBuffer, pipeline: GraphicsPipeline) void 
{
    Context.self.vkd.cmdBindPipeline(
        self.handle, 
        .graphics, 
        pipeline.handle
    );

    self.pipeline_layout = pipeline.layout;

    Context.self.vkd.cmdBindDescriptorSets(
        self.handle, 
        .graphics,
        pipeline.layout, 
        0, 
        @intCast(u32, pipeline.descriptor_sets.len), 
        pipeline.descriptor_sets.ptr, 
        0, 
        undefined
    );

    self.is_graphics_pipeline = true;
}

pub fn setVertexBuffer(self: CommandBuffer, buffer: Buffer) void 
{
    Context.self.vkd.cmdBindVertexBuffers(self.handle, 0, 1, @ptrCast([*]const vk.Buffer, &buffer.handle), @ptrCast([*]const u64, &@as(u64, 0)));
}

pub fn setPushData(self: CommandBuffer, comptime T: type, data: T) void 
{
    const shader_stages: vk.ShaderStageFlags = if (self.is_graphics_pipeline) .{ .vertex_bit = true, .fragment_bit = true } else .{ .compute_bit = true };

    Context.self.vkd.cmdPushConstants(
        self.handle, 
        self.pipeline_layout, 
        shader_stages, 
        0, 
        @sizeOf(T), 
        &data
    );
}

pub fn setViewport(self: CommandBuffer, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) void 
{
    Context.self.vkd.cmdSetViewport(self.handle, 0, 1, @ptrCast([*]const vk.Viewport, &.{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
        .min_depth = min_depth,
        .max_depth = max_depth,
    }));
}

pub fn setScissor(self: CommandBuffer, x: u32, y: u32, width: u32, height: u32) void 
{
    Context.self.vkd.cmdSetScissor(self.handle, 0, 1, @ptrCast([*]const vk.Rect2D, &.{
        .offset = .{ .x = x, .y = y },
        .extent = .{ .width = width, .height = height }
    }));
}

pub const IndexType = enum 
{
    u16,
    u32,
};

pub fn setIndexBuffer(self: CommandBuffer, buffer: Buffer, index_type: IndexType) void
{
    Context.self.vkd.cmdBindIndexBuffer(self.handle, buffer.handle, 0, switch (index_type)
    {
        .u16 => .uint16,
        .u32 => .uint32,
    });
}

pub fn copyBuffer(self: CommandBuffer, source: Buffer, source_offset: usize, destination: Buffer, destination_offset: usize) void 
{
    const copy_region = vk.BufferCopy 
    {
        .src_offset = source_offset,
        .dst_offset = destination_offset,
        .size = @min(source.size, destination.size),
    };

    Context.self.vkd.cmdCopyBuffer(self.handle, source.handle, destination.handle, 1, @ptrCast([*]const vk.BufferCopy, &copy_region));
}

pub fn updateBuffer(self: CommandBuffer, destination: Buffer, offset: usize, comptime T: type, data: []const T) void 
{
    std.debug.assert((data.len * @sizeOf(T)) <= 65536);

    Context.self.vkd.cmdUpdateBuffer(self.handle, destination.handle, offset, data.len * @sizeOf(T), data.ptr);
}

pub fn fillBuffer(self: CommandBuffer, source: Buffer, offset: usize, size: usize, value: u32) void 
{
    Context.self.vkd.cmdFillBuffer(self.handle, source.handle, offset, size, value);
}

// pub fn bufferBarrier(self: CommandBuffer, source: Buffer) void 
// {

// }

pub fn copyBufferToImage(self: CommandBuffer, source: Buffer, destination: Image) void
{
    Context.self.vkd.cmdCopyBufferToImage2(self.handle, &.{
        .src_buffer = source.handle,
        .dst_image = destination.handle,
        .dst_image_layout = .transfer_dst_optimal,
        .region_count = 1,
        .p_regions = &[_]vk.BufferImageCopy2
        {
            .{
                .buffer_offset = 0,
                .buffer_row_length = destination.width,
                .buffer_image_height = destination.height,
                .image_subresource = .{
                    .aspect_mask = .{
                        .color_bit = true,
                    },
                    .mip_level = 0,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
                .image_offset = .{ .x = 0, .y = 0, .z = 0, },
                .image_extent = .{ .width = destination.width, .height = destination.height, .depth = destination.depth },
            }
        },
    });

    //We may want to give the caller control over this barrier 
    Context.self.vkd.cmdPipelineBarrier2(
            self.handle, 
            &.{
                .dependency_flags = .{ .by_region_bit = true, },
                .memory_barrier_count = 0,
                .p_memory_barriers = undefined,
                .buffer_memory_barrier_count = 0,
                .p_buffer_memory_barriers = undefined,
                .image_memory_barrier_count = 1,
                .p_image_memory_barriers = @ptrCast([*]const vk.ImageMemoryBarrier2, &vk.ImageMemoryBarrier2
                {
                    .src_stage_mask = .{
                        .copy_bit = true,
                    },
                    .dst_access_mask = .{},
                    .dst_stage_mask = .{},
                    .src_access_mask = .{
                        .transfer_write_bit = true,
                    },
                    .old_layout = .transfer_dst_optimal,
                    .new_layout = destination.layout,
                    .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .image = destination.handle,
                    .subresource_range = .{
                        .aspect_mask = destination.aspect_mask,
                        .base_mip_level = 0,
                        .level_count = vk.REMAINING_MIP_LEVELS,
                        .base_array_layer = 0,
                        .layer_count = vk.REMAINING_ARRAY_LAYERS,
                    },
                }),
            }
        );
}

pub fn draw(
    self: CommandBuffer,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
) void 
{
    Context.self.vkd.cmdDraw(self.handle, vertex_count, instance_count, first_vertex, first_instance);
}

pub fn drawIndexed(
    self: CommandBuffer,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    vertex_offset: i32,
    first_instance: u32,
) void 
{
    Context.self.vkd.cmdDrawIndexed(
        self.handle,
        index_count,
        instance_count,
        first_index,
        vertex_offset,
        first_instance,
    );
}

pub const DrawIndexedIndirectCommand = extern struct
{
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    vertex_offset: i32,
    first_instance: u32, 
};

pub fn drawIndexedIndirect(
    self: CommandBuffer,
    draw_buffer: Buffer,
    draw_buffer_offset: usize,
    draw_count: usize,
) void 
{
    Context.self.vkd.cmdDrawIndexedIndirect(
        self.handle, 
        draw_buffer.handle, 
        draw_buffer_offset,
        @truncate(u32, draw_count),
        @sizeOf(DrawIndexedIndirectCommand),
    );
}

pub fn drawIndexedIndirectCount(
    self: CommandBuffer,
    draw_buffer: Buffer,
    draw_buffer_offset: usize,
    draw_buffer_stride: usize,
    count_buffer: Buffer,
    count_buffer_offset: usize,
    max_draw_count: usize,
) void 
{
    Context.self.vkd.cmdDrawIndexedIndirectCount(
        self.handle, 
        draw_buffer.handle, 
        draw_buffer_offset, 
        count_buffer.handle, 
        count_buffer_offset, 
        @truncate(u32, max_draw_count),
        @intCast(u32, draw_buffer_stride),
    );
}

pub fn setComputePipeline(self: *CommandBuffer, pipeline: ComputePipeline) void 
{
    Context.self.vkd.cmdBindPipeline(
        self.handle, 
        .compute, 
        pipeline.handle
    );

    self.pipeline_layout = pipeline.layout;
    self.local_size_x = pipeline.local_size_x;
    self.local_size_y = pipeline.local_size_y;
    self.local_size_z = pipeline.local_size_z;

    Context.self.vkd.cmdBindDescriptorSets(
        self.handle, 
        .compute,
        pipeline.layout, 
        0, 
        @intCast(u32, pipeline.descriptor_sets.len), 
        pipeline.descriptor_sets.ptr, 
        0, 
        undefined
    );

    self.is_graphics_pipeline = false;
}

pub fn computeDispatch(self: CommandBuffer, thread_count_x: u32, thread_count_y: u32, thread_count_z: u32) void 
{
    const group_count_x = (thread_count_x + self.local_size_x - 1) / self.local_size_x; 
    const group_count_y = (thread_count_y + self.local_size_y - 1) / self.local_size_y; 
    const group_count_z = (thread_count_z + self.local_size_z - 1) / self.local_size_z; 

    Context.self.vkd.cmdDispatch(self.handle, group_count_x, group_count_y, group_count_z);
}