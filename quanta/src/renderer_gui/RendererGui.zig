const RendererGui = @This();

const std = @import("std");
const graphics = @import("../graphics.zig");
const window = @import("../windowing.zig").window;

var self: @This() = undefined;

const RectanglePipelinePushData = extern struct 
{
    render_target_width: f32,
    render_target_height: f32,
};

const rectangle_vert_spv = @alignCast(4, @embedFile("spirv/rectangle.vert.spv"));
const rectangle_frag_spv = @alignCast(4, @embedFile("spirv/rectangle.frag.spv"));

allocator: std.mem.Allocator,
rectangle_pipeline: graphics.GraphicsPipeline,
///Should use double buffering of course, but that will be a big change
///and I want to create a solution common to all renderers in the engine
command_buffer: graphics.CommandBuffer,

pub fn init(allocator: std.mem.Allocator) !void 
{
    self.allocator = allocator;
    self.rectangle_pipeline = try graphics.GraphicsPipeline.init(
        allocator, 
        .{
            .color_attachment_formats = &.{},
            .vertex_shader_binary = rectangle_vert_spv,
            .fragment_shader_binary = rectangle_frag_spv,
            .depth_state = .{
                .write_enabled = false,
                .test_enabled = false,
                .compare_op = .greater,
            },
            .rasterisation_state = .{
                .polygon_mode = .fill,
            },
        },
        null, 
        RectanglePipelinePushData,
    );
    errdefer self.rectangle_pipeline.deinit(self.allocator);

    self.command_buffer = try graphics.CommandBuffer.init(.graphics);
    errdefer self.command_buffer.deinit();
}

pub fn deinit() void 
{
    defer self.rectangle_pipeline.deinit(self.allocator);
    defer self.command_buffer.deinit();
}

pub fn begin() void 
{

}

pub fn end() !void 
{
    {
        try self.command_buffer.begin();
        defer self.command_buffer.end();

        //#Color Pass 1: main 
        {
            self.command_buffer.beginRenderPass(
                0, 
                0, 
                window.getWidth(), 
                window.getHeight(), 
                &.{
                    .{
                        .image = undefined,
                    }
                }, 
                null
            );
            defer self.command_buffer.endRenderPass();

            self.command_buffer.setGraphicsPipeline(self.rectangle_pipeline);
            self.command_buffer.setPushData(RectanglePipelinePushData, .{
                .render_target_width = @intToFloat(f32, window.getWidth()),
                .render_target_height = @intToFloat(f32, window.getHeight()),
            });

            self.command_buffer.draw(3, 1, 0, 0);
        }
    }
}

///All coordinates are 16 bit "pixel" coordinates, which are local or global depending 
///on the Pipeline
pub const Rectangle = extern struct 
{
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    color: u32,
};

pub fn drawRectangle(rectangle: Rectangle) void 
{
    _ = rectangle;
}