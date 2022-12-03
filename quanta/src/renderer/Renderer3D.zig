const Renderer3D = @This();

const std = @import("std");
const window = @import("../windowing/window.zig");
const graphics = @import("../graphics.zig");
const GraphicsContext = graphics.Context;
const Image = graphics.Image;
const Sampler = graphics.Sampler;
const vk = graphics.vulkan;
const zalgebra = @import("zalgebra");
const options = @import("options");

const depth_reduce_comp_spv = @alignCast(4, @embedFile("spirv/depth_reduce.comp.spv"));

const depth_vert_spv = @alignCast(4, @embedFile("spirv/depth.vert.spv"));
const depth_frag_spv = @alignCast(4, @embedFile("spirv/depth.frag.spv"));

const SkyPipelinePushConstants = extern struct 
{
    view_projection: [4][4]f32,
};

const DepthPassPushConstants = extern struct 
{
    view_projection: [4][4]f32,
};

const ColorPassPushConstants = extern struct
{
    view_projection: [4][4]f32 align(1),
    point_light_count: u32 align(1),
    view_position: [3]f32 align(1),
};

const DepthReducePushData = extern struct 
{
    image_size: [2]f32,
	image_index: u32,
};

const DrawCullPushConstants = extern struct 
{
    draw_count: u32,
    near_face: [4]f32,
    far_face: [4]f32,
    right_face: [4]f32,
    left_face: [4]f32,
    top_face: [4]f32,
    bottom_face: [4]f32,
    post_depth_local_size_x: u32,
};

const PostDepthCullPushConstants = extern struct 
{
    post_depth_draw_command_offset: u32,
};

const InputDraw = extern struct 
{
    mesh_index: u32,
};

const DrawCommand = extern struct 
{
    indirect_command: graphics.CommandBuffer.DrawIndexedIndirectCommand,
    instance_index: u32,
};

pub var self: Renderer3D = undefined;

allocator: std.mem.Allocator,
swapchain: *graphics.Swapchain,
depth_image: graphics.Image,
depth_pyramid: graphics.Image,
depth_pyramid_levels: []Image.View,
depth_pyramid_level_count: u32,
command_buffers: []graphics.CommandBuffer, 
frame_fence: graphics.Fence,

transfer_command_buffer: graphics.CommandBuffer,
image_transfer_events: std.ArrayListUnmanaged(graphics.Event),

image_staging_buffers: std.ArrayListUnmanaged(graphics.Buffer),
image_staging_fence: graphics.Fence,

vertex_position_staging_buffers: std.ArrayListUnmanaged(graphics.Buffer),
vertex_staging_buffers: std.ArrayListUnmanaged(graphics.Buffer),
index_staging_buffers: std.ArrayListUnmanaged(graphics.Buffer),
mesh_staging_fence: graphics.Fence,

vertex_position_buffer: graphics.Buffer,
vertex_position_offset: usize,
vertex_buffer: graphics.Buffer,
vertex_offset: usize,
index_buffer: graphics.Buffer,
index_offset: usize,

depth_reduce_sampler: graphics.Sampler,

depth_reduce_pipeline: graphics.ComputePipeline,
cull_pipeline: graphics.ComputePipeline,
post_depth_cull_pipeline: graphics.ComputePipeline,
depth_pipeline: graphics.GraphicsPipeline,
color_pipeline: graphics.GraphicsPipeline,
sky_pipeline: graphics.GraphicsPipeline,

meshes: std.ArrayListUnmanaged(Mesh),
mesh_buffer: graphics.Buffer,

mesh_lods: std.ArrayListUnmanaged(MeshLod),
mesh_lod_buffer: graphics.Buffer,

materials: std.ArrayListUnmanaged(Material),
materials_buffer: graphics.Buffer,

scenes: std.ArrayListUnmanaged(Scene),

albedo_images: std.ArrayListUnmanaged(Image),
albedo_samplers: std.ArrayListUnmanaged(Sampler),

camera: Camera,

mesh_data_changed: bool,
material_data_changed: bool,

statistics: Statistics,
timeline_query_pool: vk.QueryPool,

fn previousPow2(v: u32) u32
{
	var r: u32 = 1;

	while (r * 2 < v)
		r *= 2;

	return r;
}

fn getImageMipLevels(width: u32, height: u32) u32
{
    var current_width = width;
    var current_height = height;

	var result: u32 = 1;

	while (current_width > 1 or current_height > 1)
	{
		result += 1;
		current_width /= 2;
		current_height /= 2;
	}

	return result;
}

fn initFrameImages(window_width: u32, window_height: u32) !void 
{
    const render_width = window_width;
    const render_height = window_height;

    self.depth_image = try Image.init(
        .@"2d",
        render_width, render_height, 1, 1,
        vk.Format.d32_sfloat, 
        vk.ImageLayout.attachment_optimal,
        .{  
            .depth_stencil_attachment_bit = true,
            .sampled_bit = true,
        }
    );
    errdefer self.depth_image.deinit();

    const depth_pyramid_width = previousPow2(render_width);
    const depth_pyramid_height = previousPow2(render_height);

    self.depth_pyramid_level_count = getImageMipLevels(depth_pyramid_width, depth_pyramid_height);

    self.depth_pyramid = try Image.init(
        .@"2d",
        depth_pyramid_width, depth_pyramid_height, 1,
        self.depth_pyramid_level_count,
        vk.Format.r32_sfloat, 
        .general,
        .{
            .transfer_src_bit = true, 
            .storage_bit = true, 
            .sampled_bit = true, 
        }
    );
    errdefer self.depth_pyramid.deinit();

    self.depth_pyramid_levels = try self.allocator.alloc(graphics.Image.View, self.depth_pyramid.levels);
    errdefer self.allocator.free(self.depth_pyramid_levels);

    for (self.depth_pyramid_levels) |*pyramid_level, i|
    {
        pyramid_level.* = try self.depth_pyramid.createView(@intCast(u32, i), 1);

        if (i == 0)
        {
            self.depth_reduce_pipeline.setDescriptorImageSampler(1, 0, self.depth_image, self.depth_reduce_sampler);
        }
        else 
        {
            self.depth_reduce_pipeline.setDescriptorImageViewSampler(1, @intCast(u32, i), self.depth_pyramid_levels[i - 1], self.depth_reduce_sampler);
        }

        self.depth_reduce_pipeline.setDescriptorImageView(0, @intCast(u32, i), self.depth_pyramid_levels[i]);
    }

    errdefer for (self.depth_pyramid_levels) |*pyramid_level|
    {
        self.depth_pyramid.destroyView(pyramid_level);
    };
}

fn deinitFrameImages() void
{
    defer self.depth_image.deinit();
    defer self.depth_pyramid.deinit();
    defer self.allocator.free(self.depth_pyramid_levels);
    defer for (self.depth_pyramid_levels) |pyramid_level|
    {
        self.depth_pyramid.destroyView(pyramid_level);
    };
}

pub fn init(
    allocator: std.mem.Allocator,
    swapchain: *graphics.Swapchain
) !void 
{
    self.allocator = allocator;
    self.swapchain = swapchain;
    self.vertex_offset = 0;
    self.index_offset = 0;
    self.vertex_position_offset = 0;
    self.mesh_data_changed = false;
    self.material_data_changed = false;
    self.image_transfer_events = .{}; 
    self.vertex_position_staging_buffers = .{};
    self.vertex_staging_buffers = .{};
    self.index_staging_buffers = .{};

    self.depth_reduce_pipeline = try graphics.ComputePipeline.init(
        self.allocator, 
        depth_reduce_comp_spv, 
        .@"2d",
        null,
        DepthReducePushData
    );
    errdefer self.depth_reduce_pipeline.deinit(self.allocator);

    self.depth_reduce_sampler = try graphics.Sampler.init(.nearest, .nearest, .min);
    errdefer self.depth_reduce_sampler.deinit();

    try initFrameImages(window.getWidth(), window.getHeight());
    errdefer deinitFrameImages();

    self.command_buffers = try allocator.alloc(graphics.CommandBuffer, swapchain.swap_images.len);
    errdefer allocator.free(self.command_buffers);

    self.materials = .{};
    self.albedo_images = .{};
    self.albedo_samplers = .{};

    for (self.command_buffers) |*command_buffer|
    {
        command_buffer.* = try graphics.CommandBuffer.init(.graphics);
    }

    errdefer for (self.command_buffers) |*command_buffer|
    {
        command_buffer.deinit();
    };

    self.transfer_command_buffer = try graphics.CommandBuffer.init(.transfer);
    errdefer self.transfer_command_buffer.deinit();

    self.image_staging_buffers = .{};
    self.image_staging_fence = try graphics.Fence.init();
    errdefer self.image_staging_fence.deinit();

    self.frame_fence = try graphics.Fence.init();
    errdefer self.frame_fence.deinit();

    self.mesh_buffer = try graphics.Buffer.init(4096, .storage);
    errdefer self.mesh_buffer.deinit();

    self.mesh_lod_buffer = try graphics.Buffer.init(4096 * 4, .storage);
    errdefer self.mesh_lod_buffer.deinit();

    const vertex_buffer_size = 32 * 1024 * 1024;

    self.vertex_position_buffer = try graphics.Buffer.init(vertex_buffer_size, .vertex);
    errdefer self.vertex_position_buffer.deinit();

    self.vertex_buffer = try graphics.Buffer.init(vertex_buffer_size, .vertex);
    errdefer self.vertex_buffer.deinit();

    self.index_buffer = try graphics.Buffer.init(vertex_buffer_size, .index);
    errdefer self.index_buffer.deinit();

    self.cull_pipeline = try graphics.ComputePipeline.init(
        self.allocator, 
        @alignCast(4, @embedFile("spirv/pre_depth_cull.comp.spv")), 
        .@"1d",
        null,
        DrawCullPushConstants
    );
    errdefer self.cull_pipeline.deinit(self.allocator);

    self.post_depth_cull_pipeline = try graphics.ComputePipeline.init(
        self.allocator, 
        @alignCast(4, @embedFile("spirv/post_depth_cull.comp.spv")), 
        .@"1d",
        null,
        PostDepthCullPushConstants
    );
    errdefer self.post_depth_cull_pipeline.deinit(self.allocator);

    self.post_depth_cull_pipeline.setDescriptorBuffer(1, 0, self.mesh_buffer);
    self.post_depth_cull_pipeline.setDescriptorImageSampler(2, 0, self.depth_pyramid, self.depth_reduce_sampler);

    self.color_pipeline = try graphics.GraphicsPipeline.init(
        self.allocator,
        .{
            .color_attachment_formats = &[_]vk.Format 
            {
                swapchain.surface_format.format,
            },
            .depth_attachment_format = self.depth_image.format,
            .vertex_shader_binary = @alignCast(4, @import("renderer_shaders").tri_vert_spv),
            .fragment_shader_binary = @alignCast(4, @embedFile(options.renderer_tri_frag_spv_path)),
            .depth_state = .{
                .write_enabled = false,
                .test_enabled = true,
                .compare_op = .greater_or_equal,
            },
            .rasterisation_state = .{
                .polygon_mode = .fill,
                .cull_mode = .back,
            },
        },
        null,
        ColorPassPushConstants,
    );
    errdefer self.color_pipeline.deinit(allocator);

    self.sky_pipeline = try graphics.GraphicsPipeline.init(
        self.allocator,
        .{
            .color_attachment_formats = &[_]vk.Format 
            {
                swapchain.surface_format.format,
            },
            .depth_attachment_format = self.depth_image.format,
            .vertex_shader_binary = @alignCast(4, @embedFile("spirv/sky.vert.spv")),
            .fragment_shader_binary = @alignCast(4, @embedFile("spirv/sky.frag.spv")),
            .depth_state = .{
                .write_enabled = false,
                .test_enabled = true,
                .compare_op = .greater_or_equal,
            },
            .rasterisation_state = .{
                .polygon_mode = .fill,
                .cull_mode = .back,
            },
        },
        null,
        SkyPipelinePushConstants,
    );
    errdefer self.sky_pipeline.deinit(allocator);

    self.depth_pipeline = try graphics.GraphicsPipeline.init(
        self.allocator,
        .{
            .color_attachment_formats = &.{},
            .depth_attachment_format = self.depth_image.format,
            .vertex_shader_binary = depth_vert_spv,
            .fragment_shader_binary = depth_frag_spv,
            .depth_state = .{
                .write_enabled = true,
                .test_enabled = true,
                .compare_op = .greater,
            },
            .rasterisation_state = .{
                .polygon_mode = .fill,
                .cull_mode = .back,
            },
        },
        null,
        DepthPassPushConstants,
    );
    errdefer self.depth_pipeline.deinit(allocator);

    self.materials_buffer = try graphics.Buffer.init(1024 * @sizeOf(Material), .storage);
    errdefer self.materials_buffer.deinit();

    self.color_pipeline.setDescriptorBuffer(0, 0, self.vertex_position_buffer);
    self.color_pipeline.setDescriptorBuffer(1, 0, self.vertex_buffer);
    self.color_pipeline.setDescriptorBuffer(5, 0, self.materials_buffer);

    self.depth_pipeline.setDescriptorBuffer(0, 0, self.vertex_position_buffer);

    self.cull_pipeline.setDescriptorBuffer(1, 0, self.mesh_buffer);
    self.cull_pipeline.setDescriptorBuffer(2, 0, self.mesh_lod_buffer);

    self.timeline_query_pool = try GraphicsContext.self.vkd.createQueryPool(
        GraphicsContext.self.device, 
        &vk.QueryPoolCreateInfo
        {
            .flags = vk.QueryPoolCreateFlags {},
            .query_type = vk.QueryType.timestamp,
            .query_count = 4,
            .pipeline_statistics = vk.QueryPipelineStatisticFlags {},
        },
        &GraphicsContext.self.allocation_callbacks
    );
    errdefer GraphicsContext.self.vkd.destroyQueryPool(GraphicsContext.self.device, self.timeline_query_pool, &GraphicsContext.self.allocation_callbacks);
}

pub fn deinit() void 
{
    defer self = undefined;
    defer self.allocator.free(self.command_buffers);
    defer deinitFrameImages();
    defer for (self.command_buffers) |*command_buffer|
    {
        command_buffer.deinit();
    };

    for (self.image_staging_buffers.items) |*staging_buffer|
    {
        staging_buffer.deinit();
    }

    for (self.image_transfer_events.items) |*event|
    {
        event.deinit();
    }

    for (self.vertex_position_staging_buffers.items) |*staging|
    {
        staging.deinit();
    }

    for (self.vertex_staging_buffers.items) |*staging|
    {
        staging.deinit();
    }

    for (self.index_staging_buffers.items) |*staging|
    {
        staging.deinit();
    }
    
    defer self.image_staging_buffers.deinit(self.allocator);
    defer self.transfer_command_buffer.deinit();
    defer self.image_staging_fence.deinit();
    defer self.frame_fence.deinit();
    defer self.image_transfer_events.deinit(self.allocator);
    defer self.vertex_position_staging_buffers.deinit(self.allocator);
    defer self.vertex_staging_buffers.deinit(self.allocator);
    defer self.index_staging_buffers.deinit(self.allocator);
    defer self.mesh_buffer.deinit();
    defer self.mesh_lod_buffer.deinit();
    defer self.vertex_position_buffer.deinit();
    defer self.vertex_buffer.deinit();
    defer self.index_buffer.deinit();
    defer self.depth_reduce_sampler.deinit();
    defer self.depth_reduce_pipeline.deinit(self.allocator);
    defer self.cull_pipeline.deinit(self.allocator);
    defer self.post_depth_cull_pipeline.deinit(self.allocator);
    defer self.depth_pipeline.deinit(self.allocator);
    defer self.color_pipeline.deinit(self.allocator);
    defer self.sky_pipeline.deinit(self.allocator);
    defer self.meshes.deinit(self.allocator);
    defer self.mesh_lods.deinit(self.allocator);
    defer self.materials.deinit(self.allocator);
    defer self.materials_buffer.deinit();
    defer self.albedo_images.deinit(self.allocator);
    defer for (self.albedo_images.items) |*image|
    {
        image.deinit();
    };
    defer self.albedo_samplers.deinit(self.allocator);
    defer for (self.albedo_samplers.items) |*sampler|
    {
        sampler.deinit();
    };
    defer GraphicsContext.self.vkd.destroyQueryPool(GraphicsContext.self.device, self.timeline_query_pool, &GraphicsContext.self.allocation_callbacks);
    defer self.scenes.deinit(self.allocator);
}

pub const Camera = struct 
{
    translation: [3]f32,
    target: [3]f32,
    fov: f32,
};

pub fn beginSceneRender(scene: SceneHandle, active_views: []const View) !void 
{
    const scene_data: *Scene = &self.scenes.items[@enumToInt(scene)];

    std.debug.assert(active_views.len == 1);

    scene_data.dynamic_draw_count = 0;
    scene_data.point_light_count = 0;
    self.camera = active_views[0].camera;

    if (self.material_data_changed or self.mesh_data_changed)
    {
        {
            try self.transfer_command_buffer.begin();
            defer self.transfer_command_buffer.end();   

            if (self.mesh_data_changed)
            {
                try self.mesh_buffer.update(Mesh, 0, self.meshes.items);
                try self.mesh_lod_buffer.update(MeshLod, 0, self.mesh_lods.items);

                {
                    var offset: usize = 0;

                    for (self.vertex_position_staging_buffers.items) |staging_buffer|
                    {
                        self.transfer_command_buffer.copyBuffer(staging_buffer, 0, staging_buffer.size, self.vertex_position_buffer, offset, self.vertex_position_buffer.size);

                        offset += staging_buffer.size;
                    }
                }

                {
                    var offset: usize = 0;

                    for (self.vertex_staging_buffers.items) |staging_buffer|
                    {
                        self.transfer_command_buffer.copyBuffer(staging_buffer, 0, staging_buffer.size, self.vertex_buffer, offset, self.vertex_buffer.size);

                        offset += staging_buffer.size;
                    }
                }

                {
                    var offset: usize = 0;

                    for (self.index_staging_buffers.items) |staging_buffer|
                    {
                        self.transfer_command_buffer.copyBuffer(staging_buffer, 0, staging_buffer.size, self.index_buffer, offset, self.index_buffer.size);

                        offset += staging_buffer.size;
                    }
                }

                self.mesh_data_changed = false;
            }

            if (self.material_data_changed) 
            {
                try self.materials_buffer.update(Material, 0, self.materials.items);

                for (self.image_staging_buffers.items) |staging_buffer, i|
                {
                    self.transfer_command_buffer.copyBufferToImage(staging_buffer, self.albedo_images.items[i]);

                    GraphicsContext.self.vkd.cmdSetEvent2(
                        self.transfer_command_buffer.handle, 
                        self.image_transfer_events.items[i].handle, 
                        &.{
                            .dependency_flags = .{},
                            .memory_barrier_count = 0,
                            .p_memory_barriers = undefined,
                            .buffer_memory_barrier_count = 0,
                            .p_buffer_memory_barriers = undefined,
                            .image_memory_barrier_count = 1,
                            .p_image_memory_barriers = &[_]vk.ImageMemoryBarrier2 
                            {
                                .{
                                    .src_stage_mask = .{
                                        .copy_bit = true,
                                    },
                                    .src_access_mask = .{
                                        .transfer_write_bit = true,
                                    },
                                    .dst_access_mask = .{},
                                    .dst_stage_mask = .{},
                                    .old_layout = .transfer_dst_optimal,
                                    .new_layout = self.albedo_images.items[i].layout,
                                    .src_queue_family_index = GraphicsContext.self.transfer_family_index.?,
                                    .dst_queue_family_index = GraphicsContext.self.graphics_family_index.?,
                                    .image = self.albedo_images.items[i].handle,
                                    .subresource_range = .{
                                        .aspect_mask = self.albedo_images.items[i].aspect_mask,
                                        .base_mip_level = 0,
                                        .level_count = vk.REMAINING_MIP_LEVELS,
                                        .base_array_layer = 0,
                                        .layer_count = vk.REMAINING_ARRAY_LAYERS,
                                    },
                                }
                            },
                        }
                    );
                }
        
                self.material_data_changed = false;
            }
        }

        self.image_staging_fence.reset();
        try self.transfer_command_buffer.submit(self.image_staging_fence);
    }
}

fn perspectiveProjection(fovy_degrees: f32, aspect_ratio: f32, znear: f32) zalgebra.Mat4 
{
    const f = 1 / std.math.tan(std.math.degreesToRadians(f32, fovy_degrees) / 2);

    return .{
        .data = .{
            .{ f / aspect_ratio, 0, 0, 0 },
            .{ 0, f, 0, 0 },
            .{ 0, 0, 0, -1 },
            .{ 0, 0, znear, 0 },
        },
    };
}

fn vectorLength(p: @Vector(4, f32)) f32
{
    return @sqrt(@reduce(.Add, p * p));
}

fn vectorCross(a: @Vector(3, f32), b: @Vector(3, f32)) @Vector(3, f32)
{
    const x1 = a[0];
    const y1 = a[1];
    const z1 = a[2];

    const x2 = b[0];
    const y2 = b[1];
    const z2 = b[2];

    const result_x = (y1 * z2) - (z1 * y2);
    const result_y = (z1 * x2) - (x1 * z2);
    const result_z = (x1 * y2) - (y1 * x2);

    return @Vector(3, f32) { result_x, result_y, result_z };
}

fn normalizePlane(p: @Vector(4, f32)) @Vector(4, f32) 
{
    return p / @splat(4, vectorLength(.{ p[0], p[1], p[2], 0 }));
}

fn extractPlanesFromProjmat(
        proj: [4][4]f32,
        view: [4][4]f32,
        left: *[4]f32, right: *[4]f32,
        bottom: *[4]f32, top: *[4]f32,
        near: *[4]f32, far: *[4]f32) void
{
    const mat = zalgebra.Mat4.mul(zalgebra.Mat4 { .data = proj }, zalgebra.Mat4.transpose(.{ .data = view })).data;

    var i: usize = 0;

    i = 3;
    while (i > 0) : (i -= 1) left[i]   = mat[i][3] + mat[i][0];
    i = 3;
    while (i > 0) : (i -= 1) right[i]  = mat[i][3] - mat[i][0];
    i = 3;
    while (i > 0) : (i -= 1) bottom[i] = mat[i][3] + mat[i][1];
    i = 3;
    while (i > 0) : (i -= 1) top[i]    = mat[i][3] - mat[i][1];
    i = 3;
    while (i > 0) : (i -= 1) near[i]   = mat[i][3] + mat[i][2];
    i = 3;
    while (i > 0) : (i -= 1) far[i]    = mat[i][3] - mat[i][2];
}

fn createPlane(p1: @Vector(3, f32), normal: @Vector(3, f32)) [4]f32
{
    const normalized_normal = zalgebra.Vec3.norm(.{ .data = normal }).data;
    const distance = zalgebra.Vec3.dot(.{ .data = normalized_normal }, .{ .data = p1 });

    return .{ normalized_normal[0], normalized_normal[1], normalized_normal[2], distance };
}

pub fn endSceneRender(scene: SceneHandle) void 
{
    endRenderInternal(scene) catch unreachable;
}

fn endRenderInternal(scene: SceneHandle) !void
{
    const scene_data: *Scene = &self.scenes.items[@enumToInt(scene)];

    if (self.image_staging_fence.getStatus() == true)
    {
        self.material_data_changed = false;
        self.mesh_data_changed = false;

        for (self.image_staging_buffers.items) |*staging_buffer|
        {
            staging_buffer.deinit();
        }
        self.image_staging_buffers.clearRetainingCapacity();

        for (self.image_transfer_events.items) |*event|
        {
            event.deinit();
        }
        self.image_transfer_events.clearRetainingCapacity();

        for (self.vertex_position_staging_buffers.items) |*staging|
        {
            staging.deinit();
        }
        self.vertex_position_staging_buffers.clearRetainingCapacity();

        for (self.vertex_staging_buffers.items) |*staging|
        {
            staging.deinit();
        }
        self.vertex_staging_buffers.clearRetainingCapacity();

        for (self.index_staging_buffers.items) |*staging|
        {
            staging.deinit();
        }
        self.index_staging_buffers.clearRetainingCapacity();
    }

    const image_index = self.swapchain.image_index;
    const image = self.swapchain.swap_images[image_index];
    const command_buffer = &self.command_buffers[image_index];

    const aspect_ratio: f32 = @intToFloat(f32, window.getWidth()) / @intToFloat(f32, window.getHeight());  
    const near_plane: f32 = 0.01;
    const far_plane: f32 = 1000;

    _ = far_plane;

    const fov: f32 = self.camera.fov;
    const projection = perspectiveProjection(fov, aspect_ratio, near_plane);
    const view_projection = projection.mul(
        zalgebra.lookAt(
            .{ .data = self.camera.translation }, 
            .{ .data = self.camera.target }, 
            .{ .data = .{ 0, -1, 0 } }, //May be problematic, we could flip the ndc clip space instead using vk_maintenence_4 
        )
    );

    //sneaky hack due to our incomplete swapchain abstraction
    var color_image: Image = undefined;

    color_image.view = image.view;
    color_image.handle = image.image;
    color_image.aspect_mask = .{ .color_bit = true };

    {
        command_buffer.begin() catch unreachable;
        defer command_buffer.end();

        GraphicsContext.self.vkd.cmdResetQueryPool(command_buffer.handle, self.timeline_query_pool, 0, 4);

        //compute pass #1 pre depth per instance cull
        {

            command_buffer.setComputePipeline(self.cull_pipeline);
            
            command_buffer.fillBuffer(scene_data.draw_indirect_count_buffer, 0, @sizeOf(u32) * 2, 0);

            command_buffer.bufferBarrier(scene_data.draw_indirect_count_buffer, .{
                .source_stage = .{ .copy = true },
                .source_access = .{ .transfer_write = true },
                .destination_stage = .{ .compute_shader = true },
                .destination_access = .{ .shader_read = true, .shader_write = true },
            });

            var near_face: [4]f32 = .{ 0, 0, 0, 0 };
            var far_face: [4]f32 = .{ 0, 0, 0, 0 };
            var right_face: [4]f32 = .{ 0, 0, 0, 0 };
            var left_face: [4]f32 = .{ 0, 0, 0, 0 };
            var top_face: [4]f32 = .{ 0, 0, 0, 0 };
            var bottom_face: [4]f32 = .{ 0, 0, 0, 0 };

            // extractPlanesFromProjmat(view_projection.data, view_projection.data, &left_face, &right_face, &bottom_face, &top_face, &near_face, &far_face);

            const front = @as(@Vector(3, f32), self.camera.target) - @as(@Vector(3, f32), self.camera.translation);

            near_face = createPlane(self.camera.translation + (@splat(3, near_plane) * front), front);

            command_buffer.setPushData(DrawCullPushConstants, .{ 
                .draw_count = scene_data.static_draw_count + scene_data.dynamic_draw_count,
                .near_face = near_face,
                .far_face = far_face,
                .right_face = right_face,
                .left_face = left_face,
                .top_face = top_face,
                .bottom_face = bottom_face,
                .post_depth_local_size_x = self.post_depth_cull_pipeline.local_size_x,
            });
            command_buffer.computeDispatch(scene_data.static_draw_count + scene_data.dynamic_draw_count, 1, 1);

            command_buffer.bufferBarrier(scene_data.draw_indirect_buffer, .{
                .source_stage = .{ .compute_shader = true },
                .source_access = .{ .shader_write = true },
                .destination_stage = .{ .draw_indirect = true, .vertex_shader = true },
                .destination_access = .{ .indirect_command_read = true, .shader_read = true },
            });
            command_buffer.bufferBarrier(scene_data.draw_indirect_count_buffer, .{
                .source_stage = .{ .compute_shader = true },
                .source_access = .{ .shader_write = true },
                .destination_stage = .{ .draw_indirect = true },
                .destination_access = .{ .indirect_command_read = true },
            });
        }

        //Depth pass #1
        {
            command_buffer.imageBarrier(
                self.depth_image, 
                .{
                    .source_stage = .{ .all_commands = true },
                    .source_access = .{},
                    .destination_stage = .{ .color_attachment_output = true },
                    .destination_access = .{ .color_attachment_write = true },
                    .destination_layout = .attachment_optimal,
                }
            );

            command_buffer.beginRenderPass(
                0, 
                0, 
                window.getWidth(), 
                window.getHeight(), 
                &.{},
                .{
                    .image = &self.depth_image,
                    .clear = .{ .depth = 0 },
                }
            );
            defer command_buffer.endRenderPass();

            command_buffer.setViewport(0, 0, @intToFloat(f32, window.getWidth()), @intToFloat(f32, window.getHeight()), 0, 1);
            command_buffer.setScissor(0, 0, window.getWidth(), window.getHeight());
            command_buffer.setGraphicsPipeline(self.depth_pipeline);
            command_buffer.setIndexBuffer(self.index_buffer, .u32);
            command_buffer.setPushData(DepthPassPushConstants, .{
                .view_projection = view_projection.data,
            });

            GraphicsContext.self.vkd.cmdWriteTimestamp2(command_buffer.handle, vk.PipelineStageFlags2
            {
                .top_of_pipe_bit = true,
            }, self.timeline_query_pool, 0);

            command_buffer.drawIndexedIndirectCount(
                scene_data.draw_indirect_buffer, 
                0, 
                @sizeOf(DrawCommand),
                scene_data.draw_indirect_count_buffer,
                0,
                scene_data.static_draw_count + scene_data.dynamic_draw_count
            );

            GraphicsContext.self.vkd.cmdWriteTimestamp2(command_buffer.handle, vk.PipelineStageFlags2
            {
                .bottom_of_pipe_bit = true,
            }, self.timeline_query_pool, 1);
        }

        //Depth reduce
        {
            command_buffer.imageBarrier(self.depth_image, .{
                .source_stage = .{ .late_fragment_tests = true },
                .source_access = .{ .depth_attachment_write = true },
                .source_layout = .attachment_optimal,
                .destination_stage = .{ .compute_shader = true },
                .destination_access = .{ .shader_read = true },
                .destination_layout = .shader_read_only_optimal,
            });

            command_buffer.imageBarrier(self.depth_pyramid, .{
                .source_stage = .{ .compute_shader = true },
                .source_access = .{ .shader_read = true },
                .source_layout = .general,
                .destination_stage = .{ .compute_shader = true },
                .destination_access = .{ .shader_write = true },
                .destination_layout = .general,
            });

            command_buffer.setComputePipeline(self.depth_reduce_pipeline);

            for (self.depth_pyramid_levels) |_, i|
            {
                const pyramid_level_width: u32 = @max(1, self.depth_pyramid.width >> @intCast(u5, i));
                const pyramid_level_height: u32 = @max(1, self.depth_pyramid.height >> @intCast(u5, i));

                command_buffer.setPushData(DepthReducePushData, .{
                    .image_size = .{ @intToFloat(f32, pyramid_level_width), @intToFloat(f32, pyramid_level_height) },
                    .image_index = @intCast(u32, i),
                });
                command_buffer.computeDispatch(pyramid_level_width, pyramid_level_height, 1);

                command_buffer.imageBarrier(self.depth_pyramid, .{
                    .layer = 0,
                    .source_stage = .{ .compute_shader = true },
                    .source_access = .{ .shader_write = true },
                    .source_layout = .general,
                    .destination_stage = .{ .compute_shader = true },
                    .destination_access = .{ .shader_read = true },
                    .destination_layout = .general,
                });
            }
        }

        //Post depth per instance cull #1
        {
            command_buffer.bufferBarrier(scene_data.draw_indirect_buffer, .{
                .source_stage = .{ .draw_indirect = true, .vertex_shader = true },
                .source_access = .{ .indirect_command_read = true, .shader_read = true },
                .destination_stage = .{ .compute_shader = true },
                .destination_access = .{ .shader_write = true, .shader_read = true },
            });

            command_buffer.bufferBarrier(scene_data.post_depth_cull_dispatch_buffer, .{
                .source_stage = .{ .compute_shader = true },
                .source_access = .{ .shader_write = true },
                .destination_stage = .{  .compute_shader = true  },
                .destination_access = .{ .shader_read = true },
            });

            command_buffer.setComputePipeline(self.post_depth_cull_pipeline);
            command_buffer.setPushData(PostDepthCullPushConstants, .{ .post_depth_draw_command_offset = scene_data.post_depth_draw_command_offset });
            //Use dispatch indirect to set count in pre-depth cull instead of conservatively
            command_buffer.computeDispatch(scene_data.static_draw_count + scene_data.dynamic_draw_count, 1, 1);

            // command_buffer.computeDispatchIndirect(scene_data.post_depth_cull_dispatch_buffer, 0);

            command_buffer.bufferBarrier(scene_data.draw_indirect_buffer, .{
                .source_stage = .{ .compute_shader = true },
                .source_access = .{ .shader_write = true },
                .destination_stage = .{ .draw_indirect = true, .vertex_shader = true },
                .destination_access = .{ .indirect_command_read = true, .shader_read = true },
            });

            command_buffer.bufferBarrier(scene_data.draw_indirect_count_buffer, .{
                .source_stage = .{ .compute_shader = true },
                .source_access = .{ .shader_write = true },
                .destination_stage = .{ .draw_indirect = true },
                .destination_access = .{ .indirect_command_read = true },
            });
        }

        //Deferred Color Pass
        {

        }

        //Forward Color Pass
        {
            command_buffer.imageBarrier(color_image, .{
                .source_stage = .{ .all_commands = true },
                .source_access = .{},
                .destination_stage = .{ .color_attachment_output = true },
                .destination_access = .{ .color_attachment_write = true },
                .destination_layout = .attachment_optimal,
            });

            command_buffer.beginRenderPass(
                0, 
                0, 
                window.getWidth(), 
                window.getHeight(), 
                &[_]graphics.CommandBuffer.Attachment {
                    .{
                        .image = &color_image,
                        .clear = if (!scene_data.environment_enabled) .{ .color = .{ 0, 0, 0, 1 } } else null
                    }
                }, 
                .{
                    .image = &self.depth_image,
                    .clear = null,
                    .store = false,
                }
            );
            defer command_buffer.endRenderPass();

            command_buffer.setViewport(0, 0, @intToFloat(f32, window.getWidth()), @intToFloat(f32, window.getHeight()), 0, 1);
            command_buffer.setScissor(0, 0, window.getWidth(), window.getHeight());

            command_buffer.setGraphicsPipeline(self.color_pipeline);
            command_buffer.setIndexBuffer(self.index_buffer, .u32);
            command_buffer.setPushData(ColorPassPushConstants, .{
                .view_projection = view_projection.data,
                .point_light_count = scene_data.point_light_count,
                .view_position = self.camera.translation,
            });

            GraphicsContext.self.vkd.cmdWriteTimestamp2(command_buffer.handle, vk.PipelineStageFlags2
            {
                .top_of_pipe_bit = true,
            }, self.timeline_query_pool, 2);

            const use_occlusion_culling = false;

            if (use_occlusion_culling)
            {
                command_buffer.drawIndexedIndirectCount(
                    scene_data.draw_indirect_buffer, 
                    scene_data.post_depth_draw_command_offset * @sizeOf(DrawCommand), 
                    @sizeOf(DrawCommand),
                    scene_data.draw_indirect_count_buffer,
                    @sizeOf(u32),
                    scene_data.static_draw_count + scene_data.dynamic_draw_count
                );
            }
            else 
            {
                command_buffer.drawIndexedIndirectCount(
                    scene_data.draw_indirect_buffer, 
                    0, 
                    @sizeOf(DrawCommand),
                    scene_data.draw_indirect_count_buffer,
                    0,
                    scene_data.static_draw_count + scene_data.dynamic_draw_count
                );
            }

            if (scene_data.environment_enabled)
            {
                const view = zalgebra.lookAt(
                    .{ .data = self.camera.translation }, 
                    .{ .data = self.camera.target }, 
                    .{ .data = .{ 0, -1, 0 } }, //May be problematic, we could flip the ndc clip space instead using vk_maintenence_4 
                );

                command_buffer.setGraphicsPipeline(self.sky_pipeline);
                command_buffer.setPushData(SkyPipelinePushConstants, 
                .{ 
                    .view_projection = projection.mul(
                        .{
                            .data = .{
                                .{ view.data[0][0], view.data[0][1], view.data[0][2], 0 },
                                .{ view.data[1][0], view.data[1][1], view.data[1][2], 0 },
                                .{ view.data[2][0], view.data[2][1], view.data[2][2], 0 },
                                .{ 0, 0, 0, 1 }
                            }
                        }
                    ).data
                });
                command_buffer.draw(36, 1, 0, 0);
            }

            GraphicsContext.self.vkd.cmdWriteTimestamp2(command_buffer.handle, vk.PipelineStageFlags2
            {
                .bottom_of_pipe_bit = true,
            }, self.timeline_query_pool, 3);
        }

        command_buffer.imageBarrier(color_image, .{
            .source_stage = .{ .color_attachment_output = true, },
            .source_access = .{  .color_attachment_write = true },
            .source_layout = .attachment_optimal,
            .destination_stage = .{},
            .destination_access = .{},
            .destination_layout = .present_src_khr,
        });
    }

    try GraphicsContext.self.vkd.queueSubmit2(GraphicsContext.self.graphics_queue, 1, &[_]vk.SubmitInfo2
    {
        .{
            .flags = .{},
            .wait_semaphore_info_count = 1,
            .p_wait_semaphore_infos = &[_]vk.SemaphoreSubmitInfo 
            {
                .{
                    .semaphore = image.image_acquired,
                    .value = 0,
                    .stage_mask = .{
                        .color_attachment_output_bit = true,
                    },
                    .device_index = 0,
                }
            },
            .command_buffer_info_count = 1,
            .p_command_buffer_infos = &[_]vk.CommandBufferSubmitInfo {
                .{
                    .command_buffer = command_buffer.handle,
                    .device_mask = 0,
                }
            },
            .signal_semaphore_info_count = 1,
            .p_signal_semaphore_infos = &[_]vk.SemaphoreSubmitInfo 
            {
                .{
                    .semaphore = image.render_finished,
                    .value = 0,
                    .stage_mask = .{
                        .color_attachment_output_bit = true,
                    },
                    .device_index = 0,
                }
            },
        }
    }, self.frame_fence.handle);

    self.frame_fence.wait();
    self.frame_fence.reset();

    var times = [_]u64 { 0, 0, 0, 0 };

    _ = try GraphicsContext.self.vkd.getQueryPoolResults(
        GraphicsContext.self.device, 
        self.timeline_query_pool, 
        0, 
        4, 
        @sizeOf(@TypeOf(times)), 
        &times, 
        @sizeOf(u64), 
        vk.QueryResultFlags { .wait_bit = true, .@"64_bit" = true }
    );

    self.statistics.depth_prepass_time = times[1] - times[0];
    self.statistics.geometry_pass_time = times[3] - times[2];
}

///Specifies a view into a scene
pub const View = struct 
{
    camera: Camera,
};

const Scene = struct 
{
    views: []View,
    
    transforms: [][4][3]f32,
    transforms_buffer: graphics.Buffer,

    material_indices: []u32,
    material_indices_buffer: graphics.Buffer,

    input_draws: []InputDraw,
    input_draw_buffer: graphics.Buffer,

    draw_indirect_buffer: graphics.Buffer,
    draw_indirect_count_buffer: graphics.Buffer,
    post_depth_cull_dispatch_buffer: graphics.Buffer,

    post_depth_draw_command_offset: u32,

    point_lights: []PointLight,
    point_light_buffer: graphics.Buffer,
    point_light_count: u32,

    environment_image: graphics.Image,
    environment_sampler: graphics.Sampler,
    environment_enabled: bool,

    max_draw_count: u32 = 0,

    static_draw_offset: u32 = 0,
    dynamic_draw_offset: u32 = 0,

    static_draw_count: u32 = 0,
    dynamic_draw_count: u32 = 0,
};

pub const SceneHandle = enum(u32) { _ }; 

///Creates a scene, statically allocating using the max parameters
///Will eventually support dynamic reallocation
pub fn createScene(
    max_view_count: u32,
    max_mesh_draw_count: u32,
    max_point_light_count: u32,
    environment_data: ?[]const u8,
    environment_width: ?u32,
    environment_height: ?u32,
) !SceneHandle 
{ 
    std.debug.assert(max_view_count == 1);

    const handle = @intToEnum(SceneHandle, @intCast(u32, self.scenes.items.len));

    var scene: Scene = undefined;

    const command_count = max_mesh_draw_count;

    scene.draw_indirect_buffer = try graphics.Buffer.init(command_count * @sizeOf(DrawCommand), .indirect);
    errdefer scene.draw_indirect_buffer.deinit();

    scene.draw_indirect_count_buffer = try graphics.Buffer.init(@sizeOf(u32) * 2, .indirect);
    errdefer scene.draw_indirect_count_buffer.deinit();

    scene.post_depth_cull_dispatch_buffer = try graphics.Buffer.init(@sizeOf(graphics.CommandBuffer.DispatchIndirectCommand), .indirect);
    errdefer scene.post_depth_cull_dispatch_buffer.deinit();

    try scene.post_depth_cull_dispatch_buffer.update(
        graphics.CommandBuffer.DispatchIndirectCommand, 0, &.{ 
            .{  
                .group_count_x = 0,
                .group_count_y = 1,
                .group_count_z = 1,
            } 
        }
    );

    scene.post_depth_draw_command_offset = command_count / 2;

    scene.input_draw_buffer = try graphics.Buffer.init(command_count * @sizeOf(InputDraw), .storage);
    errdefer scene.input_draw_buffer.deinit();

    scene.input_draws = try scene.input_draw_buffer.map(InputDraw);

    scene.transforms_buffer = try graphics.Buffer.init(command_count * @sizeOf([4][3]f32), .storage);
    errdefer scene.transforms_buffer.deinit();

    scene.transforms = try scene.transforms_buffer.map([4][3]f32);

    scene.material_indices_buffer = try graphics.Buffer.init(command_count * @sizeOf(u32), .storage);
    errdefer scene.material_indices_buffer.deinit();

    scene.material_indices = try scene.material_indices_buffer.map(u32);

    scene.environment_enabled = environment_data != null and environment_width != null and environment_width != null;
    scene.environment_image = if (scene.environment_enabled) try graphics.Image.initData(
        .cube, 
        environment_data.?,
        environment_width.?, 
        environment_height.?, 
        6, 
        1, 
        .r8g8b8a8_srgb,  
        .shader_read_only_optimal,
        .{
            .transfer_dst_bit = true, 
            .sampled_bit = true, 
        }
    ) else undefined;
    errdefer if (scene.environment_enabled) scene.environment_image.deinit();

    scene.environment_sampler = if (scene.environment_enabled) try graphics.Sampler.init(.linear, .linear, null) else undefined;
    errdefer if (scene.environment_enabled) scene.environment_sampler.deinit();

    if (scene.environment_enabled)
    {
        self.sky_pipeline.setDescriptorImageSampler(0, 0, scene.environment_image, scene.environment_sampler);
    }

    scene.point_light_buffer = try graphics.Buffer.init(max_point_light_count * @sizeOf(PointLight), .storage);
    errdefer scene.point_light_buffer.deinit();

    scene.point_lights = try scene.point_light_buffer.map(PointLight);
    errdefer scene.point_light_buffer.unmap();

    scene.point_light_count = 0;

    self.color_pipeline.setDescriptorBuffer(2, 0, scene.transforms_buffer);
    self.color_pipeline.setDescriptorBuffer(3, 0, scene.material_indices_buffer);
    self.color_pipeline.setDescriptorBuffer(4, 0, scene.draw_indirect_buffer);
    self.color_pipeline.setDescriptorBuffer(7, 0, scene.point_light_buffer);

    self.depth_pipeline.setDescriptorBuffer(1, 0, scene.transforms_buffer);
    self.depth_pipeline.setDescriptorBuffer(2, 0, scene.draw_indirect_buffer);

    self.cull_pipeline.setDescriptorBuffer(0, 0, scene.transforms_buffer);
    self.cull_pipeline.setDescriptorBuffer(3, 0, scene.draw_indirect_buffer);
    self.cull_pipeline.setDescriptorBuffer(4, 0, scene.draw_indirect_count_buffer);
    self.cull_pipeline.setDescriptorBuffer(5, 0, scene.input_draw_buffer);
    self.cull_pipeline.setDescriptorBuffer(6, 0, scene.post_depth_cull_dispatch_buffer);

    self.post_depth_cull_pipeline.setDescriptorBuffer(0, 0, scene.transforms_buffer);
    self.post_depth_cull_pipeline.setDescriptorBuffer(3, 0, scene.draw_indirect_buffer);
    self.post_depth_cull_pipeline.setDescriptorBuffer(4, 0, scene.draw_indirect_count_buffer);

    scene.max_draw_count = max_mesh_draw_count;
    scene.static_draw_count = 0;
    scene.dynamic_draw_count = 0;
    scene.static_draw_offset = 0;
    scene.dynamic_draw_offset = 0;

    try self.scenes.append(self.allocator, scene);

    return handle;
}

pub fn destroyScene(scene: SceneHandle) void 
{ 
    var scene_data = &self.scenes.items[@enumToInt(scene)];

    defer scene_data.draw_indirect_buffer.deinit();
    defer scene_data.draw_indirect_count_buffer.deinit();
    defer scene_data.post_depth_cull_dispatch_buffer.deinit();
    defer scene_data.input_draw_buffer.deinit();
    defer scene_data.transforms_buffer.deinit();
    defer scene_data.material_indices_buffer.deinit();
    defer scene_data.point_light_buffer.deinit();
    defer scene_data.point_light_buffer.unmap();
    defer if (scene_data.environment_enabled) scene_data.environment_image.deinit();
    defer if (scene_data.environment_enabled) scene_data.environment_sampler.deinit();
} 

pub const SceneMeshInstance = enum(u32) { _ };

///Add a retained mesh to the scene
pub fn sceneAddMesh(
    scene: SceneHandle, 
    mesh: MeshHandle,
    material: MaterialHandle,
    transform: zalgebra.Mat4x4(f32),
) !void 
{
    const scene_data: *Scene = &self.scenes.items[@enumToInt(scene)];

    const draw_offset = scene_data.static_draw_offset + scene_data.static_draw_count;

    scene_data.input_draws[draw_offset] = .{
        .mesh_index = @enumToInt(mesh),
    };

    scene_data.transforms[draw_offset] = .{
        transform.data[0][0..3].*,
        transform.data[1][0..3].*,
        transform.data[2][0..3].*,
        transform.data[3][0..3].*,
    };

    scene_data.material_indices[draw_offset] = @enumToInt(material);

    scene_data.static_draw_count += 1;    
} 

///Push a dynamic mesh into the scene
pub fn scenePushMesh(
    scene: SceneHandle,
    mesh: MeshHandle,
    material: MaterialHandle,
    transform: zalgebra.Mat4x4(f32),
) void 
{
    const scene_data: *Scene = &self.scenes.items[@enumToInt(scene)];

    scene_data.input_draws[scene_data.static_draw_count + scene_data.dynamic_draw_count] = .{
        .mesh_index = @enumToInt(mesh),
    };

    scene_data.transforms[scene_data.static_draw_count + scene_data.dynamic_draw_count] = .{
        transform.data[0][0..3].*,
        transform.data[1][0..3].*,
        transform.data[2][0..3].*,
        transform.data[3][0..3].*,
    };

    scene_data.material_indices[scene_data.static_draw_count + scene_data.dynamic_draw_count] = @enumToInt(material);

    scene_data.dynamic_draw_count += 1;
}

pub const PointLight = extern struct 
{
    position: [3]f32,
    intensity: f32,
    ambient: u32,
    diffuse: u32,
};

///Pushes a dynamic point light into the scene
pub fn scenePushPointLight(scene: SceneHandle, point_light: PointLight) void 
{
    const scene_data: *Scene = &self.scenes.items[@enumToInt(scene)];

    const index = scene_data.point_light_count;

    scene_data.point_lights[index] = point_light;

    scene_data.point_light_count += 1;
}

const Mesh = extern struct 
{
    vertex_offset: u32,
    vertex_count: u32,   
    lod_offset: u32,
    lod_count: u32,
    bounding_box_center: [3]f32,
    bounding_box_extents: [3]f32,
};

const MeshLod = extern struct 
{
    index_offset: u32,
    index_count: u32,
};

pub const MeshHandle = enum(u32) { _ }; 

pub fn createMesh(
    vertex_positions: []const [3]f32,
    vertices: []const Vertex,
    indices: []const u32,
    bounding_box_min: @Vector(3, f32),
    bounding_box_max: @Vector(3, f32),
) !MeshHandle
{
    const mesh_handle = @intCast(u32, self.meshes.items.len);

    const lod_offset = @intCast(u32, self.mesh_lods.items.len);
    const lod_count = 1;

    try self.mesh_lods.append(self.allocator, .{
        .index_offset = @intCast(u32, self.index_offset),
        .index_count = @intCast(u32, indices.len),
    });

    const bounding_box_center = (bounding_box_max + bounding_box_min) / @splat(3, @as(f32, 2));
    const bounding_box_extents = @Vector(3, f32) { 
        bounding_box_max[0] - bounding_box_center[0], 
        bounding_box_max[1] - bounding_box_center[1], 
        bounding_box_max[2] - bounding_box_center[2], 
    };

    try self.meshes.append(self.allocator, .{
        .vertex_offset = @intCast(u32, self.vertex_position_offset),
        .vertex_count = @intCast(u32, vertices.len),
        .lod_offset  = lod_offset,
        .lod_count = lod_count,
        .bounding_box_center = bounding_box_center,
        .bounding_box_extents = bounding_box_extents,
    });

    var vertex_positions_staging_buffer = try graphics.Buffer.initData([3]f32, vertex_positions, .staging);
    errdefer vertex_positions_staging_buffer.deinit();

    try self.vertex_position_staging_buffers.append(self.allocator, vertex_positions_staging_buffer);

    self.vertex_position_offset += vertex_positions.len;

    var vertex_staging_buffer = try graphics.Buffer.initData(Vertex, vertices, .staging);
    errdefer vertex_staging_buffer.deinit();

    try self.vertex_staging_buffers.append(self.allocator, vertex_staging_buffer);
    self.vertex_offset += vertices.len;

    var index_staging_buffer = try graphics.Buffer.initData(u32, indices, .staging);
    errdefer index_staging_buffer.deinit();

    try self.index_staging_buffers.append(self.allocator, index_staging_buffer);
    self.index_offset += indices.len;

    self.mesh_data_changed = true;

    return @intToEnum(MeshHandle, mesh_handle);
}

const Material = extern struct 
{
    albedo_texture_index: u32,
    albedo_color: u32,
};

pub const MaterialHandle = enum(u32) { _ };

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

pub fn createMaterial(
    albedo_texture_data: ?[]const u8,
    albedo_texture_width: ?u32,
    albedo_texture_height: ?u32,
    albedo_color: [4]f32,
) !MaterialHandle 
{
    const material_handle = @intCast(u32, self.materials.items.len);

    var albedo_image = try Image.init(
        .@"2d",
        albedo_texture_width orelse 1, 
        albedo_texture_height orelse 1, 
        1, 
        1,
        .r8g8b8a8_srgb, 
        .shader_read_only_optimal,
        .{
            .transfer_dst_bit = true, 
            .sampled_bit = true, 
        }
    );
    errdefer albedo_image.deinit();

    try self.albedo_images.append(self.allocator, albedo_image);

    var albedo_staging_buffer = try graphics.Buffer.initData(
        u8, 
        albedo_texture_data orelse 
        @ptrCast([*]const u8, &[_]u32 { std.math.maxInt(u32) })[0..@sizeOf(u32)], 
        .staging
    ); 
    errdefer albedo_staging_buffer.deinit();

    var albedo_transfer_event = try graphics.Event.init();
    errdefer albedo_transfer_event.deinit();

    try self.image_transfer_events.append(self.allocator, albedo_transfer_event);
    try self.image_staging_buffers.append(self.allocator, albedo_staging_buffer);

    var albedo_sampler = try Sampler.init(.nearest, .nearest, null);
    errdefer albedo_sampler.deinit();
    
    try self.albedo_samplers.append(self.allocator, albedo_sampler);

    std.log.debug("Created material {}", .{ material_handle });

    self.color_pipeline.setDescriptorImageSampler(6, material_handle, albedo_image, albedo_sampler);

    try self.materials.append(self.allocator, .{
        .albedo_texture_index = material_handle,
        .albedo_color = packUnorm4x8(albedo_color)
    });

    self.material_data_changed = true;

    return @intToEnum(MaterialHandle, material_handle);
}

pub const Vertex = extern struct 
{
    normal: [3]f32,
    color: u32,
    uv: [2]f32,
};

pub const Statistics = struct 
{
    vertex_shader_invocations: u32,
    fragment_shader_invocations: u32,
    depth_prepass_time: u64,
    geometry_pass_time: u64,
};

pub fn getStatistics() Statistics
{
    return self.statistics;
}