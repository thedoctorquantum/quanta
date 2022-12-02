const Context = @This();
const builtin = @import("builtin");
const std = @import("std");
const vk = @import("vk.zig");
const window = @import("../windowing.zig").window;
const glfw = @import("glfw");
const log = @import("../log.zig").log;

pub const enable_khronos_validation = builtin.mode == .Debug;
pub const enable_debug_messenger = enable_khronos_validation;
pub const vulkan_version = std.builtin.Version { .major = 1, .minor = 3, .patch = 0, };

const use_custom_allocator: bool = true;

pub const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceLayerProperties = true,
});

pub const InstanceDispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
    .createDevice = true,
    .destroySurfaceKHR = true,
    .enumeratePhysicalDevices = true,
    .getPhysicalDeviceProperties2 = true,
    .enumerateDeviceExtensionProperties = true,
    .getPhysicalDeviceSurfaceFormatsKHR = true,
    .getPhysicalDeviceSurfacePresentModesKHR = true,
    .getPhysicalDeviceSurfaceCapabilitiesKHR = true,
    .getPhysicalDeviceQueueFamilyProperties = true,
    .getPhysicalDeviceSurfaceSupportKHR = true,
    .getPhysicalDeviceMemoryProperties2 = true,
    .getPhysicalDeviceFeatures2 = true,
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
    .queueSubmit2 = true,
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
    .getBufferMemoryRequirements2 = true,
    .mapMemory = true,
    .unmapMemory = true,
    .bindBufferMemory = true,
    .cmdBindPipeline = true,
    .cmdDraw = true,
    .cmdSetViewport = true,
    .cmdSetScissor = true,
    .cmdBindVertexBuffers = true,
    .cmdCopyBuffer = true,
    .cmdFillBuffer = true,
    .cmdUpdateBuffer = true,
    .createImage = true,
    .getImageMemoryRequirements2 = true,
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
    .cmdDispatch = true,
    .cmdBindDescriptorSets = true,
    .allocateDescriptorSets = true,
    .freeDescriptorSets = true,
    .createDescriptorPool = true,
    .updateDescriptorSets = true,
    .cmdPipelineBarrier2 = true,
    .cmdCopyBufferToImage2 = true,
    .createSampler = true,
    .destroySampler = true,
    .cmdDispatchIndirect = true,
    .cmdDrawIndexedIndirect = true,
    .cmdDrawIndexedIndirectCount = true,
    .cmdSetEvent = true,
    .cmdSetEvent2 = true,
    .getEventStatus = true,
    .createEvent = true,
    .destroyEvent = true,
    .getFenceStatus = true,
    .createQueryPool = true,
    .destroyQueryPool = true,
    .cmdWriteTimestamp2 = true,
    .resetQueryPool = true,
    .cmdResetQueryPool = true,
    .cmdBeginQuery = true,
    .cmdEndQuery = true,
    .getQueryPoolResults = true,
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
        log.err("{s} {s}", .{ p_callback_data.?.p_message_id_name orelse "", p_callback_data.?.p_message });
        std.os.exit(0);
    }
    else if (message_severity.warning_bit_ext)
    {
        log.warn("{s} {s}", .{ p_callback_data.?.p_message_id_name orelse "", p_callback_data.?.p_message });
        std.os.exit(0);
    }
    else
    {
        log.debug("{s} {s}", .{ p_callback_data.?.p_message_id_name orelse "", p_callback_data.?.p_message });
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
    _ = user_data;

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
    _ = user_data;

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

    _ = user_data;

    const pointer = @ptrCast([*]u8, memory.?) - @sizeOf(usize);
    const size = @ptrCast(*usize, @alignCast(@alignOf(usize), pointer)).*;

    self.allocator.free(pointer[0..size + @sizeOf(usize)]);
}

pub var self: Context = undefined;

allocator: std.mem.Allocator, 
vulkan_loader: std.DynLib,
vkb: BaseDispatch,
vki: InstanceDispatch,
vkd: DeviceDispatch,
allocation_callbacks: vk.AllocationCallbacks,
instance: vk.Instance,
device: vk.Device,
physical_device: vk.PhysicalDevice,
physical_device_properties: vk.PhysicalDeviceProperties,
physical_device_subgroup_properties: vk.PhysicalDeviceSubgroupProperties,
physical_device_features: vk.PhysicalDeviceFeatures,
physical_device_memory_properties: vk.PhysicalDeviceMemoryProperties,
surface: vk.SurfaceKHR,
surface_capabilities: vk.SurfaceCapabilitiesKHR,
surface_format: vk.SurfaceFormatKHR,
surface_present_mode: vk.PresentModeKHR,
graphics_family_index: ?u32,
present_family_index: ?u32,
compute_family_index: ?u32,
transfer_family_index: ?u32,
graphics_queue: vk.Queue,
present_queue: vk.Queue,
compute_queue: vk.Queue,
transfer_queue: vk.Queue,
graphics_command_pool: vk.CommandPool,
present_command_pool: vk.CommandPool,
compute_command_pool: vk.CommandPool,
transfer_command_pool: vk.CommandPool,
pipeline_cache: vk.PipelineCache,
debug_messenger: if (enable_debug_messenger) vk.DebugUtilsMessengerEXT else void,
memories_by_type: []std.ArrayListUnmanaged(DeviceMemory),
pages: std.ArrayListUnmanaged(DevicePageMemory),
initial_memory_budgets: []usize, 
required_extensions: RequiredExtensions,
optional_extensions: OptionalExtensions,

///Required *device* extensions
pub const RequiredExtensions = struct 
{
    khr_swapchain: [:0]const u8 = vk.extension_info.khr_swapchain.name,
};

///Optional *device* extensions
///If the extension is supported at runtime, it is kept as non-null, otherwise it's set to null
pub const OptionalExtensions = struct 
{
    ext_memory_budget: ?[:0]const u8 = vk.extension_info.ext_memory_budget.name,
};

pub fn init(allocator: std.mem.Allocator, pipeline_cache_data: []const u8) !void 
{
    self.allocator = allocator;
    self.required_extensions = .{};
    self.optional_extensions = .{};

    const vulkan_loader_path = switch (builtin.os.tag) 
    {
        .linux, .freebsd => "libvulkan.so",
        .windows => "vulkan-1.dll",
        .macos => "libvulkan.1.dylib",
        else => @compileError("Targeted os doesn't support the Khronos vulkan loader!"),
    };

    self.vulkan_loader = try std.DynLib.open(vulkan_loader_path);
    errdefer self.vulkan_loader.close();

    vkGetInstanceProcAddr = self.vulkan_loader.lookup(@TypeOf(vkGetInstanceProcAddr), "vkGetInstanceProcAddr") orelse return error.LoaderProcedureNotFound;

    self.allocation_callbacks = .{
        .p_user_data = null,
        .pfn_allocation = if (use_custom_allocator) &vulkanAllocate else null,
        .pfn_reallocation = if (use_custom_allocator) &vulkanReallocate else null,
        .pfn_free = if (use_custom_allocator) &vulkanFree else null,
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

    log.info("Vulkan Version: {}", .{ vulkan_version });
    log.info("Vulkan Instance Extentions: {s}", .{ instance_extentions });

    comptime var requested_layers: []const [*:0]const u8 = &.{};

    if (enable_khronos_validation)
    {
        requested_layers = requested_layers ++ &[_][*:0]const u8 { "VK_LAYER_KHRONOS_validation" }; 
        requested_layers = requested_layers ++ &[_][*:0]const u8 { "VK_LAYER_KHRONOS_synchronization2" }; 
    }

    log.info("layers: {s}", .{ requested_layers });

    var layers_array: [requested_layers.len][*:0]const u8 = undefined; 
    var layers: [][*:0]const u8 = layers_array[0..0]; 

    if (requested_layers.len != 0)
    {
        var layer_count: u32 = 0;

        _ = try self.vkb.enumerateInstanceLayerProperties(&layer_count, null);

        const layer_properties = try self.allocator.alloc(vk.LayerProperties, layer_count);
        defer self.allocator.free(layer_properties);

        _ = try self.vkb.enumerateInstanceLayerProperties(&layer_count, layer_properties.ptr);

        log.info("Available Layers:", .{});

        for (layer_properties) |layer_property|
        {
            log.info("  {s}", .{ layer_property.layer_name });
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
                log.err("Failed to find layer {s}", .{ layer });
            }
        }
    }

    const validation_features = [_]vk.ValidationFeatureEnableEXT
    {
        //I am getting really wierd segfaults at draw time using best practices layer
        //It seems to happen whenever the shader changes between runs, which implies something to do with pipeline_cache
        //TODO: Look into this, it's very wierd and needs time to be examined
        // .best_practices_ext,
        .synchronization_validation_ext,
        .gpu_assisted_ext,
        .gpu_assisted_reserve_binding_slot_ext
    };

    self.instance = try self.vkb.createInstance(&.{
        .p_next = if (enable_khronos_validation)
            &vk.ValidationFeaturesEXT {
                .enabled_validation_feature_count = @intCast(u32, validation_features.len),
                .p_enabled_validation_features = &validation_features,
                .disabled_validation_feature_count = 0,
                .p_disabled_validation_features = undefined,
            }
        else null,
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
                .p_user_data = null,
            },
            &self.allocation_callbacks
        );
    }

    errdefer if (enable_debug_messenger) self.vki.destroyDebugUtilsMessengerEXT(
        self.instance, 
        self.debug_messenger, 
        &self.allocation_callbacks
    );

    _ = try glfw.createWindowSurface(self.instance, window.window, @ptrCast(?*vk.AllocationCallbacks, &self.allocation_callbacks), &self.surface);
    errdefer self.vki.destroySurfaceKHR(self.instance, self.surface, &self.allocation_callbacks);

    var device_extensions_buffer: [std.meta.fields(RequiredExtensions).len + std.meta.fields(OptionalExtensions).len][*:0]const u8 = undefined;
    var device_extension_count: usize = 0;

    inline for (comptime std.meta.fieldNames(RequiredExtensions)) |field_name|
    {
        device_extensions_buffer[device_extension_count] = @field(self.required_extensions, field_name);
        device_extension_count += 1;
    }

    const device_extentions = device_extensions_buffer[0..device_extension_count];

    var device_vulkan13_features = vk.PhysicalDeviceVulkan13Features 
    {
        .dynamic_rendering = vk.TRUE, 
        .synchronization_2 = vk.TRUE,
        .maintenance_4 = vk.TRUE,
        .subgroup_size_control = vk.TRUE,
        .compute_full_subgroups = vk.TRUE,
    };

    var device_vulkan12_features = vk.PhysicalDeviceVulkan12Features
    {
        .p_next = &device_vulkan13_features,
        .draw_indirect_count = vk.TRUE,
        .scalar_block_layout = vk.TRUE,
        .shader_input_attachment_array_dynamic_indexing = vk.TRUE,
        .shader_uniform_texel_buffer_array_dynamic_indexing = vk.TRUE,
        .shader_storage_texel_buffer_array_dynamic_indexing = vk.TRUE,
        .shader_uniform_buffer_array_non_uniform_indexing = vk.TRUE,
        .shader_sampled_image_array_non_uniform_indexing = vk.TRUE,
        .shader_storage_buffer_array_non_uniform_indexing = vk.TRUE,
        .shader_storage_image_array_non_uniform_indexing = vk.TRUE,
        .shader_input_attachment_array_non_uniform_indexing = vk.TRUE,
        .shader_uniform_texel_buffer_array_non_uniform_indexing = vk.TRUE,
        .shader_storage_texel_buffer_array_non_uniform_indexing = vk.TRUE,
        .descriptor_binding_uniform_buffer_update_after_bind = vk.TRUE,
        .descriptor_binding_sampled_image_update_after_bind = vk.TRUE,
        .descriptor_binding_storage_image_update_after_bind = vk.TRUE,
        .descriptor_binding_storage_buffer_update_after_bind = vk.TRUE,
        .descriptor_binding_uniform_texel_buffer_update_after_bind = vk.TRUE,
        .descriptor_binding_storage_texel_buffer_update_after_bind = vk.TRUE,
        .descriptor_binding_update_unused_while_pending = vk.TRUE,
        .descriptor_binding_partially_bound = vk.TRUE,
        .descriptor_binding_variable_descriptor_count = vk.TRUE,
        .runtime_descriptor_array = vk.TRUE,
    };

    var device_vulkan11_features = vk.PhysicalDeviceVulkan11Features
    {
        .p_next = &device_vulkan12_features,
        .shader_draw_parameters = vk.TRUE,
    };

    log.info("Required device extensions: {s}", .{ device_extentions });
    log.info("Required device features:", .{});

    inline for ((comptime std.meta.fieldNames(@TypeOf(device_vulkan13_features))[2..])) |feature_name|
    {
        if (@field(device_vulkan13_features, feature_name) == vk.TRUE)
        {
            log.info("  {s}", .{ feature_name });
        }
    }

    //Find physical device
    {
        var physical_device_count: u32 = 0;

        _ = try self.vki.enumeratePhysicalDevices(self.instance, &physical_device_count, null);

        const physical_devices = try self.allocator.alloc(vk.PhysicalDevice, physical_device_count);
        defer self.allocator.free(physical_devices);

        _ = try self.vki.enumeratePhysicalDevices(self.instance, &physical_device_count, physical_devices.ptr);

        var found_suitable_device = false;

        log.info("Available devices:", .{});

        for (physical_devices) |physical_device, i|
        {
            var properties: vk.PhysicalDeviceProperties2 = .{
                .properties = undefined,
            };

            self.vki.getPhysicalDeviceProperties2(physical_device, &properties);

            log.info("Device [{}] {s}: api_version: {}.{}.{}.{}", .{ 
                i, 
                properties.properties.device_name, 
                vk.apiVersionMajor(properties.properties.api_version), 
                vk.apiVersionMinor(properties.properties.api_version), 
                vk.apiVersionPatch(properties.properties.api_version), 
                vk.apiVersionVariant(properties.properties.api_version), 
            });
        }

        for (physical_devices) |physical_device, i|
        {
            var subgroup_properties: vk.PhysicalDeviceSubgroupProperties = .{
                .subgroup_size = 0,
                .supported_stages = .{},
                .supported_operations = .{},
                .quad_operations_in_all_stages = vk.FALSE,
            };

            var properties: vk.PhysicalDeviceProperties2 = .{
                .p_next = &subgroup_properties,
                .properties = undefined,
            };

            self.vki.getPhysicalDeviceProperties2(physical_device, &properties);
            self.physical_device_properties = properties.properties; 
            self.physical_device_subgroup_properties = subgroup_properties;
            self.physical_device_features = self.vki.getPhysicalDeviceFeatures(physical_device);

            log.info("Device Subgroup size: {}", .{ subgroup_properties.subgroup_size });

            log.info("Device [{}] {s}: api_version: {}.{}.{}.{}", .{ 
                i, 
                self.physical_device_properties.device_name, 
                vk.apiVersionMajor(self.physical_device_properties.api_version), 
                vk.apiVersionMinor(self.physical_device_properties.api_version), 
                vk.apiVersionPatch(self.physical_device_properties.api_version), 
                vk.apiVersionVariant(self.physical_device_properties.api_version), 
            });

            if (
                vk.apiVersionMajor(self.physical_device_properties.api_version) != vulkan_version.major or
                vk.apiVersionMinor(self.physical_device_properties.api_version) != vulkan_version.minor
                )
            {
                continue;
            }

            var queue_family_count: u32 = 0;

            self.vki.getPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);

            const queue_families = try self.allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
            defer self.allocator.free(queue_families);

            self.vki.getPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);

            for (queue_families) |queue_family, queue_family_index|
            {
                if (queue_family.queue_flags.graphics_bit)
                {
                    self.graphics_family_index = @intCast(u32, queue_family_index);
                }

                if (queue_family.queue_flags.compute_bit)
                {
                    self.compute_family_index = @intCast(u32, queue_family_index);
                }

                if (queue_family.queue_flags.transfer_bit)
                {
                    self.transfer_family_index = @intCast(u32, queue_family_index);
                }

                const surface_supported = try self.vki.getPhysicalDeviceSurfaceSupportKHR(
                    physical_device,
                    @intCast(u32, queue_family_index),
                    self.surface
                );

                if (surface_supported == vk.TRUE)
                {
                    self.present_family_index = @intCast(u32, queue_family_index);
                }
            }

            var physical_device_extention_count: u32 = undefined;

            _ = try self.vki.enumerateDeviceExtensionProperties(physical_device, null, &physical_device_extention_count, null);

            const physical_device_extentions = try self.allocator.alloc(vk.ExtensionProperties, physical_device_extention_count);
            defer self.allocator.free(physical_device_extentions);

            _ = try self.vki.enumerateDeviceExtensionProperties(physical_device, null, &physical_device_extention_count, physical_device_extentions.ptr);

            const supports_extentions = block:  for (device_extentions) |required_extention|
            {
                for (physical_device_extentions) |physical_device_extention|
                {                    
                    const sentinel_index = std.mem.indexOfSentinel(u8, 0, required_extention);

                    if (std.mem.eql(u8, physical_device_extention.extension_name[0..sentinel_index], required_extention[0..sentinel_index]))
                    {
                        break: block true;
                    }
                } else
                {
                    log.info("Device {s} doesn't support required extention {s}", .{ self.physical_device_properties.device_name, required_extention });

                    break: block false;
                }
            } else false;

            var physical_device_memory_properties: vk.PhysicalDeviceMemoryProperties2 = .{
                .memory_properties = undefined,
            };

            self.vki.getPhysicalDeviceMemoryProperties2(physical_device, &physical_device_memory_properties);

            self.physical_device_memory_properties = physical_device_memory_properties.memory_properties;
            self.surface_capabilities = try self.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, self.surface);

            var surface_format_count: u32 = 0;

            _ = try self.vki.getPhysicalDeviceSurfaceFormatsKHR(physical_device, self.surface, &surface_format_count, null);

            const surface_formats = try self.allocator.alloc(vk.SurfaceFormatKHR, surface_format_count);
            defer self.allocator.free(surface_formats);

            _ = try self.vki.getPhysicalDeviceSurfaceFormatsKHR(physical_device, self.surface, &surface_format_count, surface_formats.ptr);

            var surface_present_mode_count: u32 = 0;

            _ = try self.vki.getPhysicalDeviceSurfacePresentModesKHR(physical_device, self.surface, &surface_present_mode_count, null);

            const surface_present_modes = try self.allocator.alloc(vk.PresentModeKHR, surface_present_mode_count);
            defer self.allocator.free(surface_present_modes);

            _ = try self.vki.getPhysicalDeviceSurfacePresentModesKHR(physical_device, self.surface, &surface_present_mode_count, surface_present_modes.ptr);

            if (surface_formats.len == 0 or surface_present_modes.len == 0)
            {
                continue;
            }

            for (surface_formats) |surface_format|
            {
                if (surface_format.format == .b8g8r8a8_srgb and surface_format.color_space == .srgb_nonlinear_khr)
                {
                    self.surface_format = surface_format;

                    break;
                }
            }

            for (surface_present_modes) |surface_present_mode|
            {
                log.info("  surface_present_mode: {}", .{ surface_present_mode });

                if (surface_present_mode == .mailbox_khr or surface_present_mode == .fifo_khr)
                {
                    self.surface_present_mode = surface_present_mode;

                    break;
                }
            }

            if (
                self.physical_device_properties.device_type == .discrete_gpu and
                self.physical_device_features.geometry_shader == 1 and
                self.graphics_family_index != null and
                self.present_family_index != null and
                self.compute_family_index != null and
                self.transfer_family_index != null and
                supports_extentions
            )
            {
                self.physical_device = physical_device;
                found_suitable_device = true;

                break;
            }
        }

        if (!found_suitable_device)
        {
            return error.FailedToFindSuitableDevice;
        }
    }

    //Create queue command pools
    {
        const queue_create_infos = [_]vk.DeviceQueueCreateInfo
        {
            .{
                .flags = .{},
                .queue_family_index = self.graphics_family_index.?,
                .queue_count = 1,
                .p_queue_priorities = @ptrCast([*]const f32, &@as(f32, 1.0)),
            },
            .{
                .flags = .{},
                .queue_family_index = self.compute_family_index.?,
                .queue_count = 1,
                .p_queue_priorities = @ptrCast([*]const f32, &@as(f32, 1.0)),
            },
        };

        log.info("self.graphics_family_index = {?}", .{ self.graphics_family_index });
        log.info("self.present_family_index = {?}", .{ self.present_family_index });
        log.info("self.compute_family_index = {?}", .{ self.compute_family_index });
        log.info("self.transfer_family_index = {?}", .{ self.transfer_family_index });

        var physical_device_features: vk.PhysicalDeviceFeatures2 = .{
            .p_next = &device_vulkan11_features,
            .features = .{},
        };

        self.vki.getPhysicalDeviceFeatures2(self.physical_device, &physical_device_features);

        var physical_device_extention_count: u32 = 0;

        _ = try self.vki.enumerateDeviceExtensionProperties(self.physical_device, null, &physical_device_extention_count, null);

        const physical_device_extentions = try self.allocator.alloc(vk.ExtensionProperties, physical_device_extention_count);
        defer self.allocator.free(physical_device_extentions);

        _ = try self.vki.enumerateDeviceExtensionProperties(self.physical_device, null, &physical_device_extention_count, physical_device_extentions.ptr);

        inline for (comptime std.meta.fieldNames(OptionalExtensions)) |field_name|
        {
            const extention_name = &@field(self.optional_extensions, field_name);
            const sentinel_index = std.mem.indexOfSentinel(u8, 0, extention_name.*.?);

            const supports_extention = block: for (physical_device_extentions) |physical_device_extention|
            {                    
                if (std.mem.eql(u8, physical_device_extention.extension_name[0..sentinel_index], extention_name.*.?[0..sentinel_index]))
                {
                    break: block true;
                }
            } else
            {
                log.info("Device {s} doesn't support optional extention {s}", .{ self.physical_device_properties.device_name, extention_name.*.? });

                extention_name.* = null;

                break: block false;
            };

            if (supports_extention)
            {
                device_extensions_buffer[device_extension_count] = @field(self.optional_extensions, field_name).?;
                device_extension_count += 1;
            }
        }

        const device_create_info = vk.DeviceCreateInfo {
            .p_next = &physical_device_features,
            .flags = .{},
            .p_queue_create_infos = &queue_create_infos,
            .queue_create_info_count = @intCast(u32, queue_create_infos.len),
            .p_enabled_features = null,
            .enabled_extension_count = @intCast(u32, device_extension_count),
            .pp_enabled_extension_names = device_extentions.ptr,
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = undefined,
        };

        self.device = try self.vki.createDevice(self.physical_device, &device_create_info, &self.allocation_callbacks);

        self.vkd = try DeviceDispatch.load(self.device, self.vki.dispatch.vkGetDeviceProcAddr);

        errdefer self.vkd.destroyDevice(self.device, &self.allocation_callbacks);

        if (self.graphics_family_index) |index|
        {
            self.graphics_queue = self.vkd.getDeviceQueue(self.device, index, 0);
            self.graphics_command_pool = try self.vkd.createCommandPool(self.device, &.{
                .flags = .{ .reset_command_buffer_bit = true },
                .queue_family_index = index,
            }, &self.allocation_callbacks);
        }

        if (self.present_family_index) |index|
        {
            self.present_queue = self.vkd.getDeviceQueue(self.device, index, 0);
            self.present_command_pool = try self.vkd.createCommandPool(self.device, &.{
                .flags = .{ .reset_command_buffer_bit = true },
                .queue_family_index = index,
            }, &self.allocation_callbacks);
        }

        if (self.compute_family_index) |index|
        {
            self.compute_queue = self.vkd.getDeviceQueue(self.device, index, 0);
            self.compute_command_pool = try self.vkd.createCommandPool(self.device, &.{
                .flags = .{ .reset_command_buffer_bit = true },
                .queue_family_index = index,
            }, &self.allocation_callbacks);
        }

        if (self.transfer_family_index) |index|
        {
            self.transfer_queue = self.vkd.getDeviceQueue(self.device, index, 0);
            self.transfer_command_pool = try self.vkd.createCommandPool(self.device, &.{
                .flags = .{ .reset_command_buffer_bit = true },
                .queue_family_index = index,
            }, &self.allocation_callbacks);
        }
    }   

    {
        @setRuntimeSafety(false);

        self.pipeline_cache = try self.vkd.createPipelineCache(
            self.device, 
            &.{
                .flags = .{},
                .initial_data_size = pipeline_cache_data.len,
                .p_initial_data = if (pipeline_cache_data.len != 0) pipeline_cache_data.ptr else undefined,
            }, 
            &self.allocation_callbacks,
        );
    }
    errdefer self.vkd.destroyPipelineCache(self.device, self.pipeline_cache, &self.allocation_callbacks);

    self.memories_by_type = try self.allocator.alloc(std.ArrayListUnmanaged(DeviceMemory), self.physical_device_memory_properties.memory_heap_count);
    errdefer self.allocator.free(self.memories_by_type);

    for (self.memories_by_type) |*memories|
    {
        memories.* = .{};
    }

    self.pages = .{};
    self.initial_memory_budgets = try self.allocator.alloc(usize, self.physical_device_memory_properties.memory_heap_count);
    errdefer self.allocator.free(self.initial_memory_budgets);

    for (self.initial_memory_budgets) |*budget, i|
    {
        budget.* = getMemoryHeapBudget(@intCast(u32, i));

        std.log.info("Budget[{}] = {}", .{ i, budget.* });
    }
}

pub fn deinit() void 
{
    self.vkd.deviceWaitIdle(self.device) catch unreachable;

    defer self.vulkan_loader.close();
    defer self.vki.destroyInstance(self.instance, &self.allocation_callbacks);
    defer if (enable_debug_messenger) self.vki.destroyDebugUtilsMessengerEXT(
        self.instance, 
        self.debug_messenger, 
        &self.allocation_callbacks
    );
    defer self.vki.destroySurfaceKHR(self.instance, self.surface, &self.allocation_callbacks);
    defer self.vkd.destroyDevice(self.device, &self.allocation_callbacks);
    defer if (self.graphics_command_pool != .null_handle) self.vkd.destroyCommandPool(self.device, self.graphics_command_pool, &self.allocation_callbacks);
    defer if (self.present_command_pool != .null_handle) self.vkd.destroyCommandPool(self.device, self.present_command_pool, &self.allocation_callbacks);
    defer if (self.compute_command_pool != .null_handle) self.vkd.destroyCommandPool(self.device, self.compute_command_pool, &self.allocation_callbacks);
    defer if (self.transfer_command_pool != .null_handle) self.vkd.destroyCommandPool(self.device, self.transfer_command_pool, &self.allocation_callbacks);
    defer self.vkd.destroyPipelineCache(self.device, self.pipeline_cache, &self.allocation_callbacks);
    defer self.allocator.free(self.memories_by_type);
    defer for (self.memories_by_type) |*memories|
    {
        for (memories.items) |*memory|
        {
            deviceFree(memory.handle);
        }

        memories.deinit(self.allocator);
    };
    defer self.pages.deinit(self.allocator);
    defer self.allocator.free(self.initial_memory_budgets);
}

pub fn imageMemoryBarrier(
    command_buffer: vk.CommandBuffer, 
    image: vk.Image,
    src_stage: vk.PipelineStageFlags2,
    dst_stage: vk.PipelineStageFlags2,
    src_access: vk.AccessFlags2,
    dst_access: vk.AccessFlags2,
    old_layout: vk.ImageLayout,
    new_layout: vk.ImageLayout,
    ) void 
{   
    self.vkd.cmdPipelineBarrier2(
        command_buffer, 
        &.{
            .dependency_flags = .{},
            .memory_barrier_count = 0,
            .p_memory_barriers = undefined,
            .buffer_memory_barrier_count = 0,
            .p_buffer_memory_barriers = undefined,
            .image_memory_barrier_count = 1,
            .p_image_memory_barriers = @ptrCast([*]const vk.ImageMemoryBarrier2, &vk.ImageMemoryBarrier2
            {
                .src_stage_mask = src_stage,
                .dst_stage_mask = dst_stage,
                .src_access_mask = src_access,
                .dst_access_mask = dst_access,
                .old_layout = old_layout,
                .new_layout = new_layout,
                .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .image = image,
                .subresource_range = .{
                    .aspect_mask = .{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = vk.REMAINING_MIP_LEVELS,
                    .base_array_layer = 0,
                    .layer_count = vk.REMAINING_ARRAY_LAYERS,
                },
            }),
        }
    );
}

pub const MemoryType = struct 
{
    index: u32,
    heap_index: u32,
};

pub fn getMemoryType(requirements: vk.MemoryRequirements, properties: vk.MemoryPropertyFlags) !MemoryType
{
    var memory_type_index: u32 = 0; 
    
    while (memory_type_index < self.physical_device_memory_properties.memory_type_count) : (memory_type_index += 1)
    {
        const memory_type = self.physical_device_memory_properties.memory_types[memory_type_index];
        const has_properties = memory_type.property_flags.contains(properties);

        if (has_properties and 
            ((@as(u32, 1) << @intCast(u5, memory_type_index)) & requirements.memory_type_bits) != 0
        )
        {
            return .{ .index = memory_type_index, .heap_index = memory_type.heap_index };
        }
    }

    return error.MemoryTypeNotFound;    
}

pub fn getMemoryTypeIndexHostPointer(host_pointer: [*]const u8, properties: vk.MemoryPropertyFlags) !u32
{
    var host_pointer_properties: vk.MemoryHostPointerPropertiesEXT = .{ .memory_type_bits = 0 };

    try self.vkd.getMemoryHostPointerPropertiesEXT(
        self.device, 
        .{ .host_allocation_bit_ext = true }, 
        @intToPtr(*anyopaque, @ptrToInt(host_pointer)), 
        &host_pointer_properties
    );

    var memory_type_index: u32 = 0; 
    
    while (memory_type_index < self.physical_device_memory_properties.memory_type_count) : (memory_type_index += 1)
    {
        const memory_type = self.physical_device_memory_properties.memory_types[memory_type_index];
        const has_properties = memory_type.property_flags.contains(properties);

        if (has_properties and 
            ((@as(u32, 1) << @intCast(u5, @bitCast(u32, memory_type_index))) & @bitCast(u32, host_pointer_properties.memory_type_bits)) != 0
        )
        {
            return memory_type_index;
        }
    }

    return error.MemoryTypeNotFound;    
}

pub fn deviceAllocateWithMemoryType(size: usize, memory_type: MemoryType, dedicated_info: ?vk.MemoryDedicatedAllocateInfo) !vk.DeviceMemory
{
    var device_memory_budget_properties: vk.PhysicalDeviceMemoryBudgetPropertiesEXT = .{
        .heap_budget = undefined,
        .heap_usage = undefined,
    };

    var device_memory_properties: vk.PhysicalDeviceMemoryProperties2 = .{
        .p_next = if (self.optional_extensions.ext_memory_budget != null) &device_memory_budget_properties else null,
        .memory_properties = undefined,
    };

    self.vki.getPhysicalDeviceMemoryProperties2(self.physical_device, &device_memory_properties);

    if (self.optional_extensions.ext_memory_budget != null)
    {
        const heap_usage = device_memory_budget_properties.heap_usage[memory_type.heap_index];
        const heap_budget = device_memory_budget_properties.heap_budget[memory_type.heap_index];

        if (heap_usage + size >= heap_budget)
        {
            return error.OutOfMemory;
        }

        log.info("gpu heap usage {}mb; budget {}mb", .{
            heap_usage / (1024 * 1024),
            heap_budget / (1024 * 1024),
        });
    }

    return try self.vkd.allocateMemory(self.device, &.{
        .p_next = if (dedicated_info != null) &dedicated_info.? else null,
        .allocation_size = size,
        .memory_type_index = memory_type.index,
    }, &self.allocation_callbacks);    
}

pub fn deviceAllocate(requirements: vk.MemoryRequirements, properties: vk.MemoryPropertyFlags) !vk.DeviceMemory
{    
    return try deviceAllocateWithMemoryType(requirements.size, try getMemoryType(requirements, properties));
}

pub fn deviceFree(memory: vk.DeviceMemory) void 
{
    self.vkd.freeMemory(self.device, memory, &self.allocation_callbacks);
}

pub fn deviceAllocateHostMemory(
    properties: vk.MemoryPropertyFlags,
    host_memory: []const u8,
) !vk.DeviceMemory
{
    const host_pointer = @intToPtr(*anyopaque, @ptrToInt(host_memory.ptr));

    return try self.vkd.allocateMemory(self.device, &.{
        .p_next = &vk.ImportMemoryHostPointerInfoEXT 
        {
            .handle_type = .{ .host_allocation_bit_ext = true },
            .p_host_pointer = host_pointer,
        },
        .allocation_size = host_memory.len,
        .memory_type_index = try getMemoryTypeIndexHostPointer(host_memory.ptr, properties),
    }, &self.allocation_callbacks);    
}

pub const DeviceMemory = struct 
{
    handle: vk.DeviceMemory,
    next_offset: usize,
    size: vk.DeviceSize,  
    mapped_address: ?[*]u8,
    ///Reference count for mapping memory
    map_count: u32,
};

pub const DevicePageMemory = struct 
{
    memory_index: u32,
    heap_index: u32,
    offset: vk.DeviceSize,
    size: vk.DeviceSize,
};

pub fn getMemoryHeapBudget(heap_index: u32) usize
{
    if (self.optional_extensions.ext_memory_budget == null)
    {
        unreachable;
    }

    var device_memory_budget_properties: vk.PhysicalDeviceMemoryBudgetPropertiesEXT = .{
        .heap_budget = undefined,
        .heap_usage = undefined,
    };

    var device_memory_properties: vk.PhysicalDeviceMemoryProperties2 = .{
        .p_next = if (self.optional_extensions.ext_memory_budget != null) &device_memory_budget_properties else null,
        .memory_properties = undefined,
    };

    self.vki.getPhysicalDeviceMemoryProperties2(self.physical_device, &device_memory_properties);

    return device_memory_budget_properties.heap_budget[heap_index] - device_memory_budget_properties.heap_usage[heap_index];
}

pub const DevicePageHandle = enum(u32) { _ };

pub fn devicePageAllocate(
    size: usize, 
    alignment: usize, 
    memory_type_bits: u32, 
    properties: vk.MemoryPropertyFlags,
    dedicated_info: ?vk.MemoryDedicatedAllocateInfo,
) !DevicePageHandle
{
    const handle = @intToEnum(DevicePageHandle, @intCast(u32, self.pages.items.len));

    const requirements = vk.MemoryRequirements { .size = size, .alignment = alignment, .memory_type_bits = memory_type_bits };
    const memory_type = try getMemoryType(requirements, properties);

    const memories = &self.memories_by_type[memory_type.heap_index];

    var page_memory_index: ?u32 = null;
    var page_memory_offset: usize = 0;

    for (memories.items) |*memory, i|
    {
        const next_offset = std.mem.alignForward(memory.next_offset, alignment);

        const new_next_offset = next_offset + size; 
        const suitable = new_next_offset <= memory.size;

        if (!suitable)
        {
            continue;
        }

        log.info("SUITABLE = {}", .{ suitable });

        page_memory_index = @intCast(u32, i);
        page_memory_offset = next_offset;

        memory.next_offset = new_next_offset;

        break;
    }

    //If there is no suitable memory, allocate a new one
    if (page_memory_index == null)
    {
        log.info("NEW ALLOC", .{});

        // const budget = self.initial_memory_budgets[memory_type.heap_index];
        // const budget = getMemoryHeapBudget(memory_type.heap_index);

        // const minimum_memory_size = budget / 8;

        // const initial_memory_size = if (memory_type.heap_index == 0 and dedicated_info == null) @max(minimum_memory_size, (alignment + size)) else size;
        const initial_memory_size = size;

        page_memory_index = @intCast(u32, memories.items.len);

        const page_memory = try deviceAllocateWithMemoryType(initial_memory_size, memory_type, dedicated_info);
        errdefer deviceFree(page_memory);

        try memories.append(self.allocator, .{
            .handle = page_memory,
            .next_offset = alignment + size,
            .size = initial_memory_size,
            .map_count = 0,
            .mapped_address = null,
        });
    }

    try self.pages.append(self.allocator, .{
        .memory_index = page_memory_index.?,
        .heap_index = memory_type.heap_index,
        .offset = page_memory_offset,
        .size = size,
    });

    return handle;
}

pub fn devicePageFree(page: DevicePageHandle) void 
{
    const memory = devicePageGetMemory(page);
    const memory_handle = &self.memories_by_type[memory.heap_index].items[memory.memory_index];

    if (memory_handle.next_offset - memory.size == memory.offset)
    {
        memory_handle.next_offset -= memory.size;
    }

    if (memory_handle.next_offset == 0)
    {
        deviceFree(memory_handle.handle);

        memory_handle.handle = .null_handle;
        memory_handle.size = 0;
    }
} 

pub fn devicePageGetMemory(page: DevicePageHandle) DevicePageMemory
{
    return self.pages.items[@enumToInt(page)];
} 

pub fn devicePageMap(page: DevicePageHandle, comptime T: type, length: usize) ![]T
{
    const page_memory = devicePageGetMemory(page);
    const memory = &self.memories_by_type[page_memory.heap_index].items[page_memory.memory_index];

    var data = @ptrCast(?[*]T, @alignCast(@alignOf(T), memory.mapped_address));

    if (memory.map_count == 0)
    {
        data = @ptrCast(?[*]T, @alignCast(@alignOf(T), try Context.self.vkd.mapMemory(
            Context.self.device, 
            memory.handle, 
            0, 
            memory.size, 
            .{}
        )));

        memory.mapped_address = @ptrCast([*]u8, data);
    }

    data.? = data.? + page_memory.offset;

    memory.map_count += 1;

    return data.?[0..length];
}

pub fn devicePageUnmap(page: DevicePageHandle) void 
{
    const page_memory = devicePageGetMemory(page);
    const memory = &self.memories_by_type[page_memory.heap_index].items[page_memory.memory_index];

    memory.map_count -= 1;

    if (memory.map_count == 0)
    {
        Context.self.vkd.unmapMemory(self.device, memory.handle);
    }
}

pub fn devicePageBindToBuffer(buffer: vk.Buffer, page: DevicePageHandle, offset: usize) !void 
{   
    const memory = devicePageGetMemory(page);
    const memory_handle = self.memories_by_type[memory.heap_index].items[memory.memory_index];

    try self.vkd.bindBufferMemory(self.device, buffer, memory_handle.handle, memory.offset + offset);
}

pub fn devicePageBindToImage(image: vk.Image, page: DevicePageHandle, offset: usize) !void 
{   
    const memory = devicePageGetMemory(page);
    const memory_handle = self.memories_by_type[memory.heap_index].items[memory.memory_index];

    try self.vkd.bindImageMemory(self.device, image, memory_handle.handle, memory.offset + offset);
}

///Allocates a page dedicated to the specified buffer resource
pub fn devicePageAllocateBuffer(buffer: vk.Buffer, properties: vk.MemoryPropertyFlags) !DevicePageHandle
{
    var dedicated_requirements: vk.MemoryDedicatedRequirements = .{
        .prefers_dedicated_allocation = vk.FALSE,
        .requires_dedicated_allocation = vk.FALSE,
    };

    var memory_requirements: vk.MemoryRequirements2 = .{
        .p_next = &dedicated_requirements,
        .memory_requirements = undefined,
    };

    Context.self.vkd.getBufferMemoryRequirements2(Context.self.device, &vk.BufferMemoryRequirementsInfo2
    {
        .buffer = buffer,
    }, &memory_requirements);

    const page = try Context.devicePageAllocate(
        memory_requirements.memory_requirements.size, 
        memory_requirements.memory_requirements.alignment, 
        memory_requirements.memory_requirements.memory_type_bits, 
        properties, 
        if (
            dedicated_requirements.prefers_dedicated_allocation == vk.TRUE or
            dedicated_requirements.requires_dedicated_allocation == vk.TRUE
            )
        .{
            .image = .null_handle,
            .buffer = buffer,
        } else null
    );
    errdefer Context.devicePageFree(page);

    try devicePageBindToBuffer(buffer, page, 0);

    return page;
} 

///Allocates a page dedicated to the specified image resource
pub fn devicePageAllocateImage(image: vk.Image, properties: vk.MemoryPropertyFlags) !DevicePageHandle
{
    var dedicated_requirements: vk.MemoryDedicatedRequirements = .{
        .prefers_dedicated_allocation = vk.FALSE,
        .requires_dedicated_allocation = vk.FALSE,
    };

    var memory_requirements: vk.MemoryRequirements2 = .{
        .p_next = &dedicated_requirements,
        .memory_requirements = undefined,
    };

    Context.self.vkd.getImageMemoryRequirements2(Context.self.device, &vk.ImageMemoryRequirementsInfo2
    {
        .image = image,
    }, &memory_requirements);

    const page = try Context.devicePageAllocate(
        memory_requirements.memory_requirements.size, 
        memory_requirements.memory_requirements.alignment, 
        memory_requirements.memory_requirements.memory_type_bits, 
        properties, 
        if (
            dedicated_requirements.prefers_dedicated_allocation == vk.TRUE or
            dedicated_requirements.requires_dedicated_allocation == vk.TRUE
            )
        .{
            .image = image,
            .buffer = .null_handle,
        } else null
    );
    errdefer Context.devicePageFree(page);

    try devicePageBindToImage(image, page, 0);

    return page;
} 

pub fn getPipelineCacheData() ![]const u8 
{
    var data: []u8 = undefined;

    _ = try self.vkd.getPipelineCacheData(self.device, self.pipeline_cache, &data.len, null);

    data = try self.allocator.alloc(u8, data.len);

    _ = try self.vkd.getPipelineCacheData(self.device, self.pipeline_cache, &data.len, @ptrCast(*anyopaque, data.ptr));

    return data;
} 