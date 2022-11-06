
pub const tri_vert_spv: []align(4) const u8 = @alignCast(4, @embedFile("shaders/spirv/tri.vert.spv"));
pub const tri_frag_spv: []align(4) const u8 = @alignCast(4, @embedFile("shaders/spirv/tri.frag.spv"));

pub const TriVertexInput = extern struct 
{
    in_position: [3]f32,
    in_color: [3]f32,
    in_uv: [2]f32,
};

pub const TriVertPushConstants = extern struct 
{
    position: [3]f32,
};