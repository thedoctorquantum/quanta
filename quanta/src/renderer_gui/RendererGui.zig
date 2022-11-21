const RendererGui = @This();

const std = @import("std");
const graphics = @import("../graphics.zig");
const window = @import("../windowing.zig").window;
const nk = @import("../nuklear.zig").nuklear;
const zalgebra = @import("../math.zig").zalgebra;
const imgui = @import("../imgui.zig").cimgui;

var self: @This() = .{};

const RectanglePipelinePushData = extern struct 
{
    render_target_width: f32,
    render_target_height: f32,
    rectangle: Rectangle,
};

const MeshPipelinePushData = extern struct 
{
    projection: [4][4]f32,
    texture_index: u32,
};

const Texture = struct 
{
    image: graphics.Image,
    sampler: graphics.Sampler,
};

allocator: std.mem.Allocator = undefined,
rectangle_pipeline: graphics.GraphicsPipeline = undefined,
mesh_pipeline: graphics.GraphicsPipeline = undefined,
///Should use double buffering of course, but that will be a big change
///and I want to create a solution common to all renderers in the engine
command_buffer: graphics.CommandBuffer = undefined,
color_target_image: *const graphics.Image = undefined,
rectangles: std.ArrayListUnmanaged(Rectangle) = .{},
scissors: std.ArrayListUnmanaged([4]u16) = .{},
rectangles_buffer: graphics.Buffer = undefined,
vertices_buffer: graphics.Buffer = undefined,
indices_buffer: graphics.Buffer = undefined,
textures: std.ArrayListUnmanaged(Texture) = .{},

nk_commands: nk.nk_buffer = undefined,
nk_vertices: nk.nk_buffer = undefined,
nk_indices: nk.nk_buffer = undefined,

pub const TextureHandle = enum(u32) { null = 0, _ };

pub fn createTexture(data: []const u8, width: u32, height: u32) !TextureHandle
{
    const handle = @intToEnum(TextureHandle, @intCast(u32, self.textures.items.len + 1));

    var image = try graphics.Image.initData(
        data,
        width, 
        height, 
        1, 
        1,
        .r8g8b8a8_srgb,
        .shader_read_only_optimal,
        .{
            .transfer_dst_bit = true, 
            .sampled_bit = true, 
        }
    );
    errdefer image.deinit();

    var sampler = try graphics.Sampler.init(.nearest, .nearest, null);
    errdefer sampler.deinit();

    try self.textures.append(self.allocator, .{ .image = image, .sampler = sampler, });

    self.mesh_pipeline.setDescriptorImageSampler(1, @enumToInt(handle) - 1, image, sampler);

    return handle;
}

pub fn init(allocator: std.mem.Allocator, swapchain: graphics.Swapchain) !void 
{
    self.allocator = allocator;
    self.rectangle_pipeline = try graphics.GraphicsPipeline.init(
        allocator, 
        .{
            .color_attachment_formats = &.{ swapchain.surface_format.format },
            .vertex_shader_binary = @alignCast(4, @embedFile("spirv/rectangle.vert.spv")),
            .fragment_shader_binary = @alignCast(4, @embedFile("spirv/rectangle.frag.spv")),
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

    self.mesh_pipeline = try graphics.GraphicsPipeline.init(
        allocator, 
        .{
            .color_attachment_formats = &.{ swapchain.surface_format.format },
            .vertex_shader_binary = @alignCast(4, @embedFile("spirv/mesh.vert.spv")),
            .fragment_shader_binary = @alignCast(4, @embedFile("spirv/mesh.frag.spv")),
            .depth_state = .{
                .write_enabled = false,
                .test_enabled = false,
                .compare_op = .greater,
            },
            .rasterisation_state = .{
                .polygon_mode = .fill,
            },
            .blend_state = .{
                .blend_enabled = true,
            },
        },
        null, 
        MeshPipelinePushData,
    );
    errdefer self.mesh_pipeline.deinit(self.allocator);

    self.command_buffer = try graphics.CommandBuffer.init(.graphics);
    errdefer self.command_buffer.deinit();

    self.rectangles_buffer = try graphics.Buffer.init(4096 * @sizeOf(Rectangle), .storage);
    errdefer self.rectangles_buffer.deinit();
    
    self.rectangle_pipeline.setDescriptorBuffer(0, 0, self.rectangles_buffer);

    const max_vertices = 50_000;
    const max_indices = 50_000;

    self.vertices_buffer = try graphics.Buffer.init(max_vertices * @sizeOf(Vertex), .storage);
    errdefer self.vertices_buffer.deinit();

    self.mesh_pipeline.setDescriptorBuffer(0, 0, self.vertices_buffer);

    self.indices_buffer = try graphics.Buffer.init(max_indices * @sizeOf(u16), .index);
    errdefer self.indices_buffer.deinit();

    nk.nk_buffer_init(&self.nk_commands, &nk_allocator, 4096 * 10);
    std.debug.assert(self.nk_commands.memory.ptr != null);
    errdefer nk.nk_buffer_free(&self.nk_commands);

    nk.nk_buffer_init(&self.nk_vertices, &nk_allocator, 4096 * 10);
    std.debug.assert(self.nk_vertices.memory.ptr != null);
    errdefer nk.nk_buffer_free(&self.nk_vertices);

    nk.nk_buffer_init(&self.nk_indices, &nk_allocator, 4096 * 10);
    std.debug.assert(self.nk_indices.memory.ptr != null);
    errdefer nk.nk_buffer_free(&self.nk_indices);
    
    try initImGui();
    errdefer deinitImGui();
}

fn initImGui() !void
{
    const io: *imgui.ImGuiIO = @ptrCast(*imgui.ImGuiIO, imgui.igGetIO());

    var pixel_pointer: [*c]u8 = undefined;
    var width: c_int = 0;
    var height: c_int = 0;
    var out_bytes_per_pixel: c_int = 0;

    imgui.ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &pixel_pointer, &width, &height, &out_bytes_per_pixel);

    const font_texture = try createTexture(pixel_pointer[0..@intCast(u32, width) * @intCast(u32, height) * @sizeOf(u32)], @intCast(u32, width), @intCast(u32, height));

    io.Fonts.*.TexID = @intToPtr(*anyopaque, @enumToInt(font_texture));
}

fn deinitImGui() void 
{

}

pub fn deinit() void 
{
    defer self.rectangle_pipeline.deinit(self.allocator);
    defer self.mesh_pipeline.deinit(self.allocator);
    defer self.command_buffer.deinit();
    defer self.rectangles_buffer.deinit();
    defer self.rectangles.deinit(self.allocator);
    defer self.vertices_buffer.deinit();
    defer self.indices_buffer.deinit();
    defer self.scissors.deinit(self.allocator);
    defer self.textures.deinit(self.allocator);
    defer for (self.textures.items) |*texture|
    {
        defer texture.image.deinit();
        defer texture.sampler.deinit();
    };
    defer nk.nk_buffer_free(&self.nk_commands);
    defer nk.nk_buffer_free(&self.nk_vertices);
    defer nk.nk_buffer_free(&self.nk_indices);
    defer deinitImGui();
}

pub fn begin(color_target_image: *const graphics.Image) void 
{
    self.color_target_image = color_target_image;
    self.rectangles.clearRetainingCapacity();
    self.scissors.clearRetainingCapacity();
}

pub const Vertex = extern struct 
{
    position: [2]f32,
    uv: [2]f32,
    color: u32,
};

fn nkAlloc(_: nk.nk_handle, _: ?*anyopaque, size: nk.nk_size) callconv(.C) ?*anyopaque
{
    return std.c.malloc(size);
}

fn nkFree(_: nk.nk_handle, ptr: ?*anyopaque) callconv(.C) void
{
    std.c.free(ptr);
}

var nk_allocator = nk.nk_allocator 
{
    .userdata = .{ .ptr = null },
    .alloc = &nkAlloc,
    .free = &nkFree,
};

//impl for nuklear
pub fn end(nk_ctx: *nk.nk_context) !void 
{
    {
        try self.command_buffer.begin();
        defer self.command_buffer.end();

        std.debug.assert(nk.nk_convert(nk_ctx, &self.nk_commands, &self.nk_vertices, &self.nk_indices, &nk.nk_convert_config
        {
            .shape_AA = nk.NK_ANTI_ALIASING_ON,
            .line_AA = nk.NK_ANTI_ALIASING_ON,
            .vertex_layout = &[_]nk.nk_draw_vertex_layout_element 
            {
                .{ .attribute = nk.NK_VERTEX_POSITION, .format = nk.NK_FORMAT_FLOAT, .offset = @offsetOf(Vertex, "position") },
                .{ .attribute = nk.NK_VERTEX_TEXCOORD, .format = nk.NK_FORMAT_FLOAT, .offset = @offsetOf(Vertex, "uv") },
                .{ .attribute = nk.NK_VERTEX_COLOR, .format = nk.NK_FORMAT_B8G8R8A8, .offset = @offsetOf(Vertex, "color") },
                .{ .attribute = nk.NK_VERTEX_ATTRIBUTE_COUNT, .format = nk.NK_FORMAT_COUNT, .offset = 0, },
            },
            .vertex_size = @sizeOf(Vertex),
            .vertex_alignment = @alignOf(Vertex),
            .circle_segment_count = 22,
            .curve_segment_count = 22,
            .arc_segment_count = 22,
            .global_alpha = 1.0,
            .tex_null = .{
                .texture = .{ .id = 0 },
                .uv = undefined,
            },
        }) == nk.NK_CONVERT_SUCCESS);
        defer nk.nk_buffer_clear(&self.nk_commands);
        defer nk.nk_buffer_clear(&self.nk_vertices);
        defer nk.nk_buffer_clear(&self.nk_indices);

        try self.vertices_buffer.update(u8, 0, @ptrCast([*]u8, self.nk_vertices.memory.ptr.?)[0..self.nk_vertices.size]);
        try self.indices_buffer.update(u8, 0, @ptrCast([*]u8, self.nk_indices.memory.ptr.?)[0..self.nk_indices.size]);
        // try self.rectangles_buffer.update(Rectangle, 0, self.rectangles.items);

        //#Color Pass 1: main 
        {
            self.command_buffer.beginRenderPass(
                0, 
                0, 
                window.getWidth(), 
                window.getHeight(), 
                &[_]graphics.CommandBuffer.Attachment 
                {
                    .{
                        .image = self.color_target_image,
                    }
                }, 
                null
            );
            defer self.command_buffer.endRenderPass();

            self.command_buffer.setGraphicsPipeline(self.mesh_pipeline);
            self.command_buffer.setViewport(
                0, 0, 
                @intToFloat(f32, window.getWidth()), 
                @intToFloat(f32, window.getHeight()), 
                0, 
                1
            );
            self.command_buffer.setScissor(0, 0, window.getWidth(), window.getHeight());

            // const projection = zalgebra.orthographic(0, @intToFloat(f32, window.getWidth()), 0, @intToFloat(f32, window.getHeight()), 0, 1);

            var ortho = [4][4]f32 
            {
                .{2.0, 0.0, 0.0, 0.0},
                .{0.0,-2.0, 0.0, 0.0},
                .{0.0, 0.0,-1.0, 0.0},
                .{-1.0,1.0, 0.0, 1.0},
            };
            ortho[0][0] /= @intToFloat(f32, window.getWidth());
            ortho[1][1] /= @intToFloat(f32, window.getHeight());

            self.command_buffer.setIndexBuffer(self.indices_buffer, .u16);

            {
                var cmd: ?*const nk.nk_draw_command = nk.nk__draw_begin(nk_ctx, &self.nk_commands);

                var index_offset: u32 = 0;

                while (cmd) |command|
                {
                    defer cmd = nk.nk__draw_next(cmd, &self.nk_commands, nk_ctx);

                    if (command.elem_count == 0) continue;

                    self.command_buffer.setPushData(MeshPipelinePushData, .{
                        .projection = ortho,
                        .texture_index = @intCast(u32, command.texture.id),
                    });

                    self.command_buffer.setScissor(
                        @floatToInt(u32, @max(command.clip_rect.x, 0)), 
                        @floatToInt(u32, @max(command.clip_rect.y, 0)), 
                        @floatToInt(u32, @min(command.clip_rect.w, @intToFloat(f32, window.getWidth()))), 
                        @floatToInt(u32, @min(command.clip_rect.h, @intToFloat(f32, window.getHeight())))
                    );

                    self.command_buffer.drawIndexed(command.elem_count, 1, index_offset, 0, 0);
                    index_offset += command.elem_count;
                }
            }

            //direct command processing
            {
            // var cmd: ?*const nk.nk_command = null;

            // cmd = nk.nk__begin(nk_ctx);

            // while (cmd) |command|
            // {
            //     switch (command.type)
            //     {
            //         nk.NK_COMMAND_RECT_FILLED => {
            //             const filled = @ptrCast(*const nk.nk_command_rect_filled, command);

            //             self.command_buffer.setPushData(RectanglePipelinePushData, .{
            //                 .render_target_width = @intToFloat(f32, window.getWidth()),
            //                 .render_target_height = @intToFloat(f32, window.getHeight()),
            //                 .rectangle = .{
            //                     .x = @intCast(u16, filled.x),
            //                     .y = @intCast(u16, filled.y),
            //                     .width = filled.w,
            //                     .height = filled.h,
            //                     .color = @bitCast(u32, filled.color)
            //                 },
            //             });

            //             self.command_buffer.draw(6, 1, 0, 0);
            //         },
            //         nk.NK_COMMAND_SCISSOR => {
            //             const command_scissor = @ptrCast(*const nk.nk_command_scissor, command);

            //             self.command_buffer.setScissor(@bitCast(u16, command_scissor.x), @bitCast(u16, command_scissor.y), command_scissor.w, command_scissor.h);
            //         },
            //         else => {},
            //     }

            //     cmd = nk.nk__next(nk_ctx, cmd);
            // }
            }
        }
    }

    //quite slow but will do for now
    try self.command_buffer.submitAndWait();
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
    border_radius: f32 = 0,
};

pub fn drawRectangle(rectangle: Rectangle) void 
{
    self.rectangles.append(self.allocator, rectangle) catch unreachable;
}

pub fn renderImGuiDrawData(draw_data: *const imgui.ImDrawData) !void 
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
                &[_]graphics.CommandBuffer.Attachment 
                {
                    .{
                        .image = self.color_target_image,
                    }
                }, 
                null
            );
            defer self.command_buffer.endRenderPass();

            self.command_buffer.setGraphicsPipeline(self.mesh_pipeline);
            self.command_buffer.setViewport(
                0, 0, 
                @intToFloat(f32, window.getWidth()), 
                @intToFloat(f32, window.getHeight()), 
                0, 
                1
            );
            self.command_buffer.setScissor(0, 0, window.getWidth(), window.getHeight());

            // const projection = zalgebra.orthographic(0, @intToFloat(f32, window.getWidth()), 0, @intToFloat(f32, window.getHeight()), 0, 1);

            var ortho = [4][4]f32 
            {
                .{2.0, 0.0, 0.0, 0.0},
                .{0.0,-2.0, 0.0, 0.0},
                .{0.0, 0.0,-1.0, 0.0},
                .{-1.0,1.0, 0.0, 1.0},
            };
            ortho[0][0] /= @intToFloat(f32, window.getWidth());
            ortho[1][1] /= @intToFloat(f32, window.getHeight());

            self.command_buffer.setIndexBuffer(self.indices_buffer, .u16);

            {
                var command_list_index: usize = 0;

                var vertex_offset: usize = 0;
                var index_offset: usize = 0;

                while (command_list_index < @intCast(usize, draw_data.CmdListsCount)) : (command_list_index += 1)
                {
                    const command_list: *imgui.ImDrawList = draw_data.CmdLists[command_list_index];
                    
                    const vertices: []imgui.ImDrawVert = command_list.VtxBuffer.Data[0..@intCast(usize, command_list.VtxBuffer.Size)];
                    const indices: []u16 = command_list.IdxBuffer.Data[0..@intCast(usize, command_list.IdxBuffer.Size)];

                    try self.vertices_buffer.update(imgui.ImDrawVert, vertex_offset * @sizeOf(imgui.ImDrawVert), vertices);
                    try self.indices_buffer.update(u16, index_offset * @sizeOf(u16), indices);

                    var command_index: usize = 0;
                    
                    while (command_index < @intCast(usize, command_list.CmdBuffer.Size)) : (command_index += 1)
                    {
                        const command: imgui.ImDrawCmd = command_list.CmdBuffer.Data[command_index];

                        self.command_buffer.setPushData(MeshPipelinePushData, .{
                            .projection = ortho,
                            .texture_index = @intCast(u32, @ptrToInt(command.TextureId)),
                        });

                        self.command_buffer.setScissor(
                            @floatToInt(u32, @max(command.ClipRect.x, 0)), 
                            @floatToInt(u32, @max(command.ClipRect.y, 0)), 
                            @floatToInt(u32, @min(command.ClipRect.z, @intToFloat(f32, window.getWidth()))) - @floatToInt(u32, @max(command.ClipRect.x, 0)), 
                            @floatToInt(u32, @min(command.ClipRect.w, @intToFloat(f32, window.getHeight()))) - @floatToInt(u32, @max(command.ClipRect.y, 0))
                        );

                        self.command_buffer.drawIndexed(command.ElemCount, 1, @intCast(u32, index_offset) + command.IdxOffset, @intCast(i32, vertex_offset) + @intCast(i32, command.VtxOffset), 0);
                    }

                    vertex_offset += vertices.len;
                    index_offset += indices.len;
                } 
            }
        }
    }

    //quite slow but will do for now
    try self.command_buffer.submitAndWait();
}