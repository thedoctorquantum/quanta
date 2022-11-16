const Archive = @This();

const std = @import("std");

pub const Header = extern struct 
{
    asset_count: u32,
};

pub const AssetSourceDescriptor = enum(u32) { _ };
pub const AssetDescriptor = enum(u32) { null, _ };

pub const AssetHeader = extern struct 
{
    source_data_size: u32,
    source_data_alignment: u32,
    mapped_data_size: u32,
    mapped_data_alignment: u32,
};

pub const AssetMappedRegion = extern struct 
{

};

pub fn init() void 
{
   
}

pub fn deinit() void 
{

}

pub fn openAsset(source: AssetSourceDescriptor) AssetDescriptor
{
    _ = source;

    return .null;
}

pub fn closeAsset(asset: AssetDescriptor) void
{
    _ = asset;
}

pub fn mapAsset(asset: AssetDescriptor) ![]const u8
{
    _ = asset;
    unreachable;
}

pub fn unmapAsset(asset: AssetDescriptor) void 
{
    _ = asset;
    unreachable;
}

pub fn isMapped(asset: AssetDescriptor) bool
{
    _ = asset;

    return true;
}

test "basic" 
{
    var test_asset: AssetDescriptor = try openAsset();
    defer closeAsset(test_asset);

    const data = try mapAsset(test_asset);
    defer unmapAsset(test_asset);

    // try formatAsset(test_asset, format_fn);

    _ = data;
}