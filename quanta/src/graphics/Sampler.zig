const Sampler = @This();

const vk = @import("vk.zig");
const Context = @import("Context.zig");

handle: vk.Sampler,

pub fn init() !Sampler 
{
    var self = Sampler
    {
        .handle = .null_handle,
    };

    self.handle = try Context.self.vkd.createSampler(
        Context.self.device, 
        &.{
            .flags = .{},
            .mag_filter = .nearest,
            .min_filter = .nearest,
            .mipmap_mode = .nearest,
            .address_mode_u = .repeat,
            .address_mode_v = .repeat,
            .address_mode_w = .repeat,
            .mip_lod_bias = 0,
            .anisotropy_enable = vk.FALSE,
            .max_anisotropy = 0,
            .compare_enable = vk.FALSE,
            .compare_op = .always,
            .min_lod = 0,
            .max_lod = 0,
            .border_color = .float_opaque_black,
            .unnormalized_coordinates = vk.FALSE,
        }, 
        &Context.self.allocation_callbacks,
    );

    return self;
}

pub fn deinit(self: *Sampler) void 
{
    defer self.* = undefined;

    defer Context.self.vkd.destroySampler(Context.self.device, self.handle, &Context.self.allocation_callbacks);
}