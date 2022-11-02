const Context = @This();
const builtin = @import("builtin");
const std = @import("std");
const vk = @import("vk.zig");

pub const enable_khronos_validation = builtin.mode == .Debug;
pub const enable_debug_messenger = enable_khronos_validation;
pub const enable_mangohud = builtin.mode == .Debug;
pub const vulkan_version = std.builtin.Version { .major = 1, .minor = 3, .patch = 0, };

pub const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceLayerProperties = true,
});

pub const InstanceDispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
    .createDevice = true,
    .destroySurfaceKHR = true,
    .enumeratePhysicalDevices = true,
    .getPhysicalDeviceProperties = true,
    .enumerateDeviceExtensionProperties = true,
    .getPhysicalDeviceSurfaceFormatsKHR = true,
    .getPhysicalDeviceSurfacePresentModesKHR = true,
    .getPhysicalDeviceSurfaceCapabilitiesKHR = true,
    .getPhysicalDeviceQueueFamilyProperties = true,
    .getPhysicalDeviceSurfaceSupportKHR = true,
    .getPhysicalDeviceMemoryProperties = true,
    .getDeviceProcAddr = true,
    .getPhysicalDeviceFeatures = true,
    .createDebugUtilsMessengerEXT = enable_debug_messenger,
    .destroyDebugUtilsMessengerEXT = enable_debug_messenger,
});

pub const DeviceDispatch = vk.DeviceWrapper(.{
    .destroyDevice = true,
    .getDeviceQueue = true,
    .createPipelineCache = true,
    .createDescriptorSetLayout = true,
    .createSemaphore = true,
    .createFence = true,
    .createImageView = true,
    .destroyImageView = true,
    .destroySemaphore = true,
    .destroyFence = true,
    .getSwapchainImagesKHR = true,
    .createSwapchainKHR = true,
    .destroySwapchainKHR = true,
    .acquireNextImageKHR = true,
    .deviceWaitIdle = true,
    .waitForFences = true,
    .resetFences = true,
    .queueSubmit = true,
    .queuePresentKHR = true,
    .createCommandPool = true,
    .destroyCommandPool = true,
    .allocateCommandBuffers = true,
    .freeCommandBuffers = true,
    .queueWaitIdle = true,
    .createShaderModule = true,
    .destroyShaderModule = true,
    .createPipelineLayout = true,
    .destroyPipelineLayout = true,
    .createRenderPass = true,
    .destroyRenderPass = true,
    .createGraphicsPipelines = true,
    .createComputePipelines = true,
    .destroyPipeline = true,
    .createFramebuffer = true,
    .destroyFramebuffer = true,
    .beginCommandBuffer = true,
    .endCommandBuffer = true,
    .allocateMemory = true,
    .freeMemory = true,
    .createBuffer = true,
    .destroyBuffer = true,
    .getBufferMemoryRequirements = true,
    .mapMemory = true,
    .unmapMemory = true,
    .bindBufferMemory = true,
    .cmdBeginRenderPass = true,
    .cmdEndRenderPass = true,
    .cmdBindPipeline = true,
    .cmdDraw = true,
    .cmdSetViewport = true,
    .cmdSetScissor = true,
    .cmdBindVertexBuffers = true,
    .cmdCopyBuffer = true,
    .createImage = true,
    .getImageMemoryRequirements = true,
    .destroyImage = true,
    .bindImageMemory = true,
    .getPipelineCacheData = true,
    .resetCommandBuffer = true,
    .cmdBindIndexBuffer = true,
    .cmdPushConstants = true,
    .cmdDrawIndexed = true,
    .destroyDescriptorPool = true,
    .destroyDescriptorSetLayout = true,
    .destroyPipelineCache = true,
    .cmdBeginRendering = true,
    .cmdEndRendering = true,
    .cmdPipelineBarrier = true,
    .cmdDispatch = true,
    .cmdBindDescriptorSets = true,
    .allocateDescriptorSets = true,
    .freeDescriptorSets = true,
    .createDescriptorPool = true,
    .updateDescriptorSets = true,
});

var vkGetInstanceProcAddr: vk.PfnGetInstanceProcAddr = undefined;

fn getInstanceProcAddress(instance: vk.Instance, name: [*:0]const u8) vk.PfnVoidFunction
{
    return vkGetInstanceProcAddr(instance, name);
}

fn debugUtilsMessengerCallback(
    message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
    message_types: vk.DebugUtilsMessageTypeFlagsEXT,
    p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
    p_user_data: ?*anyopaque
) callconv(vk.vulkan_call_conv) vk.Bool32
{
    _ = message_types;
    _ = p_user_data;

    if (message_severity.error_bit_ext)
    {
        std.debug.panic("{s} {s}", .{ p_callback_data.?.p_message_id_name.?, p_callback_data.?.p_message });
    }
    else
    {
        std.log.warn("{s} {s}", .{ p_callback_data.?.p_message_id_name.?, p_callback_data.?.p_message });
    }

    return vk.FALSE;
}

fn vulkanAllocate(
    user_data: ?*anyopaque, 
    size: usize, 
    alignment: usize, 
    _: vk.SystemAllocationScope
) callconv(vk.vulkan_call_conv) ?*anyopaque
{
    const self = @ptrCast(*Context, @alignCast(@alignOf(Context), user_data.?));

    const memory = self.allocator.rawAlloc(size + @sizeOf(usize), @intCast(u29, alignment), 0, @returnAddress()) catch
    {
        @panic("Allocation failed!");
    };

    @ptrCast(*usize, @alignCast(@alignOf(usize), memory.ptr)).* = size;

    return memory.ptr + @sizeOf(usize);
}

fn vulkanReallocate(
    user_data: ?*anyopaque, 
    original: ?*anyopaque, 
    size: usize, 
    alignment: usize, 
    _: vk.SystemAllocationScope
) callconv(vk.vulkan_call_conv) ?*anyopaque
{
    const self = @ptrCast(*Context, @alignCast(@alignOf(Context), user_data.?));

    const original_pointer = @ptrCast([*]u8, original.?) - @sizeOf(usize);
    const old_size = @ptrCast(*usize, @alignCast(@alignOf(usize), original_pointer)).*;

    const memory = self.allocator.reallocBytes(
        original_pointer[0..old_size + @sizeOf(usize)], 
        @intCast(u29, alignment), size + @sizeOf(usize), @intCast(u29, alignment), 0, @returnAddress()
    ) catch
    {
        @panic("Allocation failed!");
    };

    @ptrCast(*usize, @alignCast(@alignOf(usize), memory.ptr)).* = size;
    
    return memory.ptr + @sizeOf(usize);
}

fn vulkanFree(
    user_data: ?*anyopaque, 
    memory: ?*anyopaque
) callconv(vk.vulkan_call_conv) void
{
    if (memory == null) return;

    const self = @ptrCast(*Context, @alignCast(@alignOf(Context), user_data.?));

    const pointer = @ptrCast([*]u8, memory.?) - @sizeOf(usize);
    const size = @ptrCast(*usize, @alignCast(@alignOf(usize), pointer)).*;

    self.allocator.free(pointer[0..size + @sizeOf(usize)]);
}

allocator: std.mem.Allocator, 
vulkan_loader: std.DynLib,
vkb: BaseDispatch,
vki: InstanceDispatch,
vkd: DeviceDispatch,
allocation_callbacks: vk.AllocationCallbacks,
instance: vk.Instance,
device: vk.Device,
debug_messenger: if (enable_debug_messenger) vk.DebugUtilsMessengerEXT else void,

pub fn init(self: *Context, allocator: std.mem.Allocator) !void 
{
    self.allocator = allocator;

    const vulkan_loader_path = switch (builtin.os.tag) 
    {
        .linux, .freebsd => "libvulkan.so",
        .windows => "vulkan-1.dll",
        .macos => "libvulkan.1.dylib",
        else => @compileError("Targeted os doesn't support the KHRONOS vulkan loader!"),
    };

    self.vulkan_loader = try std.DynLib.open(vulkan_loader_path);

    vkGetInstanceProcAddr = self.vulkan_loader.lookup(@TypeOf(vkGetInstanceProcAddr), "vkGetInstanceProcAddr") orelse return error.LoaderProcedureNotFound;

    self.allocation_callbacks = .{
        .p_user_data = self,
        .pfn_allocation = vulkanAllocate,
        .pfn_reallocation = vulkanReallocate,
        .pfn_free = vulkanFree,
        .pfn_internal_allocation = null,
        .pfn_internal_free = null, 
    };

    self.vkb = try BaseDispatch.load(getInstanceProcAddress);

    comptime var instance_extentions: []const [*:0]const u8 = &.{};

    if (enable_debug_messenger)
    {
        instance_extentions = instance_extentions ++ [_][*:0]const u8 { vk.extension_info.ext_debug_utils.name };
    }

    instance_extentions = instance_extentions ++ [_][*:0]const u8 { vk.extension_info.khr_surface.name };
    instance_extentions = instance_extentions ++ [_][*:0]const u8 { vk.extension_info.khr_xcb_surface.name };

    std.log.info("Vulkan Version: {}", .{ vulkan_version });
    std.log.info("Vulkan Instance Extentions: {s}", .{ instance_extentions });

    comptime var requested_layers: []const [*:0]const u8 = &.{};

    if (enable_mangohud)
    {
        requested_layers = requested_layers ++ &[_][*:0]const u8 { "VK_LAYER_MANGOHUD_overlay" };
    }

    if (enable_khronos_validation)
    {
        requested_layers = requested_layers ++ &[_][*:0]const u8 { "VK_LAYER_KHRONOS_validation" }; 
    }

    std.log.info("layers: {s}", .{ requested_layers });

    var layers_array: [requested_layers.len][*:0]const u8 = undefined; 
    var layers: [][*:0]const u8 = layers_array[0..0]; 

    if (requested_layers.len != 0)
    {
        var layer_count: u32 = 0;

        _ = try self.vkb.enumerateInstanceLayerProperties(&layer_count, null);

        const layer_properties = try self.allocator.alloc(vk.LayerProperties, layer_count);
        defer self.allocator.free(layer_properties);

        _ = try self.vkb.enumerateInstanceLayerProperties(&layer_count, layer_properties.ptr);

        std.log.info("Available Layers:", .{});

        for (layer_properties) |layer_property|
        {
            std.log.info("  {s}", .{ layer_property.layer_name });
        }

        inline for (requested_layers) |layer|
        {
            const found = block: for (layer_properties) |layer_property|
            {
                const first_sentinel_index = std.mem.indexOfSentinel(u8, 0, layer);
                const second_sentinel_index = std.mem.indexOfSentinel(u8, 0, @ptrCast([*:0]const u8, &layer_property.layer_name));

                const sentinel_index = @min(first_sentinel_index, second_sentinel_index);

                if (std.mem.eql(u8, layer[0..sentinel_index], layer_property.layer_name[0..sentinel_index]))
                {
                    break: block true;
                }
            } else false;

            if (found)
            {
                layers_array[layers.len] = layer;
                layers.len += 1;
            }
            else
            {
                std.log.err("Failed to find layer {s}", .{ layer });
            }
        }
    }

    self.instance = try self.vkb.createInstance(&.{
        .flags = .{},
        .p_application_info = &vk.ApplicationInfo 
        {
            .api_version = vk.makeApiVersion(
                0,
                vulkan_version.major, 
                vulkan_version.minor, 
                vulkan_version.patch,
            ),
            .application_version = 0,
            .engine_version = 0,
            .p_application_name = null,
            .p_engine_name = null,
        },
        .enabled_layer_count = @intCast(u32, layers.len),
        .pp_enabled_layer_names = requested_layers.ptr,
        .enabled_extension_count = @intCast(u32, instance_extentions.len),
        .pp_enabled_extension_names = instance_extentions.ptr,
    }, &self.allocation_callbacks);

    self.vki = try InstanceDispatch.load(self.instance, getInstanceProcAddress);

    errdefer self.vki.destroyInstance(self.instance, &self.allocation_callbacks);

    if (enable_debug_messenger) 
    {
        self.debug_messenger = try self.vki.createDebugUtilsMessengerEXT(
            self.instance,
            &.{
                .flags = .{},
                .message_severity = .{ .info_bit_ext = true, .error_bit_ext = true },
                .message_type = .{ .performance_bit_ext = true, .validation_bit_ext = enable_khronos_validation },
                .pfn_user_callback = &debugUtilsMessengerCallback,
                .p_user_data = self,
            },
            &self.allocation_callbacks
        );
    }

    errdefer if (enable_debug_messenger) self.vki.destroyDebugUtilsMessengerEXT(
        self.instance, 
        self.debug_messenger, 
        &self.allocation_callbacks
    );
}

pub fn deinit(self: *Context) void 
{
    defer self.* = undefined;
    defer self.vulkan_loader.close();
    defer self.vki.destroyInstance(self.instance, &self.allocation_callbacks);
    defer if (enable_debug_messenger) self.vki.destroyDebugUtilsMessengerEXT(
        self.instance, 
        self.debug_messenger, 
        &self.allocation_callbacks
    );
}