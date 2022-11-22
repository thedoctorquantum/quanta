const Archive = @This();

const std = @import("std");

image: []u8,
assets: []AssetHeader,
asset_content: []u8,

pub const Header = extern struct 
{
    asset_count: u32,
};

pub const AssetDescriptor = enum(u32) { _ };

pub const AssetHeader = extern struct 
{
    source_data_offset: u32,
    source_data_size: u32,
    mapped_data_size: u32,
    mapped_data_alignment: u32,
};

pub const AssetMappedRegion = extern struct 
{

};

pub const AssetDescription = struct
{
    source_data: []const u8,
    source_data_alignment: u32,
    mapped_data_size: usize,
};

pub fn encode(allocator: std.mem.Allocator, assets: []const AssetDescription) ![]const u8 
{   
    var image_size: usize = @sizeOf(Header);

    image_size = std.mem.alignForward(image_size, @alignOf(AssetHeader));
    image_size += @sizeOf(AssetHeader) * assets.len;

    var source_content_size: usize = 0;

    for (assets) |asset|
    {
        const aligned_size = std.mem.alignForward(source_content_size, asset.source_data_alignment); 

        source_content_size = aligned_size + asset.source_data.len;
    }

    image_size += source_content_size;

    const image = try allocator.allocAdvanced(u8, @alignOf(Header), image_size, .at_least);
    errdefer allocator.free(image);

    var image_offset: usize = 0;

    const header = @ptrCast(*Header, @alignCast(@alignOf(Header), image.ptr));
    image_offset += @sizeOf(Header);
    image_offset = std.mem.alignForward(image_offset, @alignOf(AssetHeader));

    header.asset_count = @intCast(u32, assets.len);

    var current_content_offset: usize = image_offset + @sizeOf(AssetHeader) * assets.len;

    for (assets) |asset|
    {
        const asset_header = @ptrCast(*AssetHeader, @alignCast(@alignOf(AssetHeader), image.ptr + image_offset));

        current_content_offset = std.mem.alignForward(current_content_offset, asset.source_data_alignment);

        asset_header.source_data_size = @intCast(u32, asset.source_data.len);
        asset_header.source_data_offset = @intCast(u32, current_content_offset);
        asset_header.mapped_data_size = @intCast(u32, asset.mapped_data_size);
        asset_header.mapped_data_alignment = 1;

        @memcpy(image.ptr + asset_header.source_data_offset, asset.source_data.ptr, asset.source_data.len);

        current_content_offset += asset_header.source_data_size;

        image_offset += @sizeOf(AssetHeader);
    }

    return image;
}

pub fn decode(allocator: std.mem.Allocator, image: []u8) !Archive
{
    _ = allocator;

    var archive = Archive
    {
        .image = image,
        .assets = &.{},
        .asset_content = &.{},
    };

    var image_offset: usize = 0;

    image_offset += @sizeOf(Header);

    const header = @ptrCast(*const Header, @alignCast(@alignOf(Header), image.ptr + image_offset)).*;

    image_offset = std.mem.alignForward(image_offset, @alignOf(AssetHeader));

    archive.assets = @ptrCast([*]AssetHeader, @alignCast(@alignOf(AssetHeader), image.ptr + image_offset))[0..header.asset_count];

    image_offset += @sizeOf(AssetHeader) * header.asset_count;

    archive.asset_content = image[image_offset..];

    return archive;
}

pub fn getAssetData(self: Archive, asset: AssetDescriptor) []u8 
{
    const header = self.assets[@enumToInt(asset)];

    return self.image[header.source_data_offset..header.source_data_offset + header.source_data_size];
}