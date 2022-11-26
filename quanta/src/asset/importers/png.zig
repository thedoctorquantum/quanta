const std = @import("std");
const img = @import("zigimg");
const png = img.png;

pub const Import = struct 
{
    data: []u8,
    width: u32,
    height: u32,
};

///Also supports png because I'm lazy atm...
pub fn import(allocator: std.mem.Allocator, data: []const u8) !Import
{
    var self = Import
    {
        .data = undefined,
        .width = 0,
        .height = 0,
    };

    var image = try img.Image.fromMemory(allocator, data);
    defer image.deinit();

    std.log.debug("pixel_format: {s}", .{ @tagName(image.pixelFormat()) });

    self.data = image.pixels.asBytes();
    self.width = @intCast(u32, image.width);
    self.height = @intCast(u32, image.height);

    self.data = try allocator.alloc(u8, 4 * image.width * image.height);

    if (image.pixelFormat() == .rgb24)
    {
        for (image.pixels.rgb24) |pixel, i|
        {
            const write_pixel = @ptrCast(*img.color.Rgba32, self.data.ptr + (i * @sizeOf(img.color.Rgba32)));

            write_pixel.r = pixel.r;
            write_pixel.g = pixel.g;
            write_pixel.b = pixel.b;
            write_pixel.a = 255;
        }
    }
    else 
    { 
        std.mem.copy(u8, self.data, image.pixels.asBytes());
    }

    return self;
}
pub fn importFile(allocator: std.mem.Allocator, path: []const u8) !Import
{
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(bytes);

    return import(allocator, bytes);
}

pub fn importCubeFile(allocator: std.mem.Allocator, paths: [6][]const u8) !Import
{
    var import_data: Import = .{
        .data = &.{},
        .width = 0,
        .height = 0,
    };

    var file_imports: [6]Import = undefined;

    for (paths) |path, i|
    {
        file_imports[i] = try importFile(allocator, path);

        import_data.width = @max(import_data.width, file_imports[i].width);
        import_data.height = @max(import_data.height, file_imports[i].height);
    }

    defer for (file_imports) |*file_import|
    {
        free(file_import, allocator);
    };

    const data_size = import_data.width * import_data.height * 6 * @sizeOf(u32);
    import_data.data = try allocator.alloc(u8, data_size);
    errdefer allocator.free(import_data.data);

    var data_offset: usize = 0;

    for (file_imports) |file_import|
    {
        @memcpy(import_data.data.ptr + data_offset, file_import.data.ptr, file_import.data.len);

        data_offset += file_import.data.len;
    }

    return import_data;
}

pub fn free(self: *Import, allocator: std.mem.Allocator) void 
{
    self.* = undefined;

    _ = allocator;
    // allocator.free(self.data);
}