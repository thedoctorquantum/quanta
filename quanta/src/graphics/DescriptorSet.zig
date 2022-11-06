const DescriptorSet = @This();

const Context = @import("Context.zig");
const vk = @import("vk.zig");

handle: vk.DescriptorSet,

pub fn init(layout: vk.DescriptorSetLayout) !DescriptorSet 
{
    var self = DescriptorSet
    {
        .layout = .null_handle,
        .handle = .null_handle,
    };

    // Context.self.vkd.allocateDescriptorSets(device: Device, p_allocate_info: *const DescriptorSetAllocateInfo, p_descriptor_sets: [*]DescriptorSet)

    return self;
}

pub fn deinit(self: *DescriptorSet) void 
{
    defer self.* = undefined;
}