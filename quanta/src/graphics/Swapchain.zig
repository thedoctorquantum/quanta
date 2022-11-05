const Swapchain = @This();
const std = @import("std");
const vk = @import("vk.zig");
const Context = @import("Context.zig");

pub const PresentState = enum 
{
    optimal,
    suboptimal,
};

allocator: std.mem.Allocator,
surface_format: vk.SurfaceFormatKHR,
present_mode: vk.PresentModeKHR,
extent: vk.Extent2D,
handle: vk.SwapchainKHR,
swap_images: []SwapImage,
image_index: u32,
next_image_acquired: vk.Semaphore,

pub fn init(allocator: std.mem.Allocator, extent: vk.Extent2D) !Swapchain 
{
    return try initRecycle(allocator, extent, .null_handle);
}

pub fn initRecycle(allocator: std.mem.Allocator, extent: vk.Extent2D, old_handle: vk.SwapchainKHR) !Swapchain 
{
    const caps = try Context.self.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(Context.self.physical_device, Context.self.surface);
    const actual_extent = findActualExtent(caps, extent);
    if (actual_extent.width == 0 or actual_extent.height == 0) {
        return error.InvalidSurfaceDimensions;
    }

    const surface_format = try findSurfaceFormat(allocator);
    const present_mode = try findPresentMode(allocator);

    var image_count = caps.min_image_count + 1;
    if (caps.max_image_count > 0) {
        image_count = std.math.min(image_count, caps.max_image_count);
    }

    const qfi = [_]u32{ Context.self.graphics_family_index.?, Context.self.present_family_index.? };
    const sharing_mode: vk.SharingMode = if (Context.self.graphics_family_index.? != Context.self.present_family_index.?)
        .concurrent
    else
        .exclusive;

    std.log.info("swapchain image sharing mode: {}", .{ sharing_mode });

    const handle = try Context.self.vkd.createSwapchainKHR(Context.self.device, &.{
        .flags = .{},
        .surface = Context.self.surface,
        .min_image_count = image_count,
        .image_format = surface_format.format,
        .image_color_space = surface_format.color_space,
        .image_extent = actual_extent,
        .image_array_layers = 1,
        .image_usage = .{ .color_attachment_bit = true, .transfer_dst_bit = true },
        .image_sharing_mode = sharing_mode,
        .queue_family_index_count = qfi.len,
        .p_queue_family_indices = &qfi,
        .pre_transform = caps.current_transform,
        .composite_alpha = .{ .opaque_bit_khr = true },
        .present_mode = present_mode,
        .clipped = vk.TRUE,
        .old_swapchain = old_handle,
    }, null);
    errdefer Context.self.vkd.destroySwapchainKHR(Context.self.device, handle, null);

    if (old_handle != .null_handle) {
        // Apparently, the old swapchain handle still needs to be destroyed after recreating.
        Context.self.vkd.destroySwapchainKHR(Context.self.device, old_handle, null);
    }

    const swap_images = try initSwapchainImages(handle, surface_format.format, allocator);
    errdefer for (swap_images) |si| si.deinit();

    var next_image_acquired = try Context.self.vkd.createSemaphore(Context.self.device, &.{ .flags = .{} }, null);
    errdefer Context.self.vkd.destroySemaphore(Context.self.device, next_image_acquired, null);

    const result = try Context.self.vkd.acquireNextImageKHR(Context.self.device, handle, std.math.maxInt(u64), next_image_acquired, .null_handle);
    if (result.result != .success) {
        return error.ImageAcquireFailed;
    }

    std.mem.swap(vk.Semaphore, &swap_images[result.image_index].image_acquired, &next_image_acquired);
    
    return Swapchain
    {
        .allocator = allocator,
        .surface_format = surface_format,
        .present_mode = present_mode,
        .extent = actual_extent,
        .handle = handle,
        .swap_images = swap_images,
        .image_index = result.image_index,
        .next_image_acquired = next_image_acquired,
    };
}

fn deinitExceptSwapchain(self: Swapchain) void 
{
    for (self.swap_images) |si| si.deinit();
    Context.self.vkd.destroySemaphore(Context.self.device, self.next_image_acquired, null);
}

pub fn waitForAllFences(self: Swapchain) !void 
{
    for (self.swap_images) |si| si.waitForFence(self.context) catch {};
}

pub fn deinit(self: Swapchain) void 
{
    self.deinitExceptSwapchain();
    Context.self.vkd.destroySwapchainKHR(Context.self.device, self.handle, null);
    self.allocator.free(self.swap_images);
}

pub fn recreate(self: *Swapchain, new_extent: vk.Extent2D) !void 
{
    const allocator = self.allocator;
    const old_handle = self.handle;
    self.deinitExceptSwapchain();
    self.* = try initRecycle(allocator, new_extent, old_handle);
}

pub fn currentImage(self: Swapchain) vk.Image 
{
    return self.swap_images[self.image_index].image;
}

pub fn currentSwapImage(self: Swapchain) *const SwapImage 
{
    return &self.swap_images[self.image_index];
}

pub fn present(self: *Swapchain, cmdbuf: vk.CommandBuffer) !PresentState 
{
    // Simple method:
    // 1) Acquire next image
    // 2) Wait for and reset fence of the acquired image
    // 3) Submit command buffer with fence of acquired image,
    //    dependendent on the semaphore signalled by the first step.
    // 4) Present current frame, dependent on semaphore signalled by previous step
    // Problem: This way we can't reference the current image while rendering.
    // Better method: Shuffle the steps around such that acquire next image is the last step,
    // leaving the swapchain in a state with the current image.
    // 1) Wait for and reset fence of current image
    // 2) Submit command buffer, signalling fence of current image and dependent on
    //    the semaphore signalled by step 4.
    // 3) Present current frame, dependent on semaphore signalled by the submit
    // 4) Acquire next image, signalling its semaphore
    // One problem that arises is that we can't know beforehand which semaphore to signal,
    // so we keep an extra auxilery semaphore that is swapped around

    // Step 1: Make sure the current frame has finished rendering
    const current = self.currentSwapImage();
    // try current.waitForFence(self.context);
    // try self.context.vkd.resetFences(self.context.device, 1, @ptrCast([*]const vk.Fence, &current.frame_fence));

    // Step 2: Submit the command buffer
    const wait_stage = [_]vk.PipelineStageFlags{.{ .top_of_pipe_bit = true }};
    try self.context.vkd.queueSubmit(self.context.graphics_queue, 1, &[_]vk.SubmitInfo{.{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = @ptrCast([*]const vk.Semaphore, &current.image_acquired),
        .p_wait_dst_stage_mask = &wait_stage,
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &cmdbuf),
        .signal_semaphore_count = 1,
        .p_signal_semaphores = @ptrCast([*]const vk.Semaphore, &current.render_finished),
    }}, current.frame_fence);

    // Step 3: Present the current frame
    _ = try self.context.vkd.queuePresentKHR(self.context.present_queue, &.{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = @ptrCast([*]const vk.Semaphore, &current.render_finished),
        .swapchain_count = 1,
        .p_swapchains = @ptrCast([*]const vk.SwapchainKHR, &self.handle),
        .p_image_indices = @ptrCast([*]const u32, &self.image_index),
        .p_results = null,
    });

    return .optimal;

    //return switch (result.result) {
    //    .success => .optimal,
    //    .suboptimal_khr => .suboptimal,
    //    else => unreachable,
    //};
}

pub const SwapImage = struct 
{
    image: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,
    render_finished: vk.Semaphore,
    frame_fence: vk.Fence,

    fn init(image: vk.Image, format: vk.Format) !SwapImage {
        const view = try Context.self.vkd.createImageView(Context.self.device, &.{
            .flags = .{},
            .image = image,
            .view_type = .@"2d",
            .format = format,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        }, null);
        errdefer Context.self.vkd.destroyImageView(Context.self.device, view, null);

        const image_acquired = try Context.self.vkd.createSemaphore(Context.self.device, &.{ .flags = .{} }, null);
        errdefer Context.self.vkd.destroySemaphore(Context.self.device, image_acquired, null);

        const render_finished = try Context.self.vkd.createSemaphore(Context.self.device, &.{ .flags = .{} }, null);
        errdefer Context.self.vkd.destroySemaphore(Context.self.device, render_finished, null);

        const frame_fence = try Context.self.vkd.createFence(Context.self.device, &.{ .flags = .{ .signaled_bit = true } }, null);
        errdefer Context.self.vkd.destroyFence(Context.self.device, frame_fence, null);

        return SwapImage
        {
            .image = image,
            .view = view,
            .image_acquired = image_acquired,
            .render_finished = render_finished,
            .frame_fence = frame_fence,
        };
    }

    fn deinit(self: SwapImage) void 
    {
        self.waitForFence() catch return;
        Context.self.vkd.destroyImageView(Context.self.device, self.view, null);
        Context.self.vkd.destroySemaphore(Context.self.device, self.image_acquired, null);
        Context.self.vkd.destroySemaphore(Context.self.device, self.render_finished, null);
        Context.self.vkd.destroyFence(Context.self.device, self.frame_fence, null);
    }

    pub fn waitForFence(self: SwapImage) !void 
    {
        _ = try Context.self.vkd.waitForFences(Context.self.device, 1, @ptrCast([*]const vk.Fence, &self.frame_fence), vk.TRUE, std.math.maxInt(u64));
    }
};

fn initSwapchainImages(swapchain: vk.SwapchainKHR, format: vk.Format, allocator: std.mem.Allocator) ![]SwapImage 
{
    var count: u32 = undefined;
    _ = try Context.self.vkd.getSwapchainImagesKHR(Context.self.device, swapchain, &count, null);
    const images = try allocator.alloc(vk.Image, count);
    defer allocator.free(images);
    _ = try Context.self.vkd.getSwapchainImagesKHR(Context.self.device, swapchain, &count, images.ptr);

    const swap_images = try allocator.alloc(SwapImage, count);
    errdefer allocator.free(swap_images);

    var i: usize = 0;
    errdefer for (swap_images[0..i]) |si| si.deinit();

    for (images) |image| {
        swap_images[i] = try SwapImage.init(image, format);
        i += 1;
    }

    return swap_images;
}

fn findSurfaceFormat(allocator: std.mem.Allocator) !vk.SurfaceFormatKHR 
{
    const preferred = vk.SurfaceFormatKHR{
        .format = .b8g8r8a8_srgb,
        .color_space = .srgb_nonlinear_khr,
    };

    var count: u32 = undefined;
    _ = try Context.self.vki.getPhysicalDeviceSurfaceFormatsKHR(Context.self.physical_device, Context.self.surface, &count, null);
    const surface_formats = try allocator.alloc(vk.SurfaceFormatKHR, count);
    defer allocator.free(surface_formats);
    _ = try Context.self.vki.getPhysicalDeviceSurfaceFormatsKHR(Context.self.physical_device, Context.self.surface, &count, surface_formats.ptr);

    for (surface_formats) |sfmt| {
        if (std.meta.eql(sfmt, preferred)) {
            return preferred;
        }
    }

    return surface_formats[0]; // There must always be at least one supported surface format
}

fn findPresentMode(allocator: std.mem.Allocator) !vk.PresentModeKHR 
{
    var count: u32 = undefined;
    _ = try Context.self.vki.getPhysicalDeviceSurfacePresentModesKHR(Context.self.physical_device, Context.self.surface, &count, null);
    const present_modes = try allocator.alloc(vk.PresentModeKHR, count);
    defer allocator.free(present_modes);
    _ = try Context.self.vki.getPhysicalDeviceSurfacePresentModesKHR(Context.self.physical_device, Context.self.surface, &count, present_modes.ptr);

    const preferred = [_]vk.PresentModeKHR{
        .mailbox_khr,
        .immediate_khr,
    };

    for (preferred) |mode| {
        if (std.mem.indexOfScalar(vk.PresentModeKHR, present_modes, mode) != null) {
            return mode;
        }
    }

    return .fifo_khr;
}

fn findActualExtent(caps: vk.SurfaceCapabilitiesKHR, extent: vk.Extent2D) vk.Extent2D 
{
    if (caps.current_extent.width != 0xFFFF_FFFF) {
        return caps.current_extent;
    } else {
        return .{
            .width = std.math.clamp(extent.width, caps.min_image_extent.width, caps.max_image_extent.width),
            .height = std.math.clamp(extent.height, caps.min_image_extent.height, caps.max_image_extent.height),
        };
    }
}