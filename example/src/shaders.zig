
pub const tri_vert_spv: []align(4) const u8 = @alignCast(4, @embedFile("shaders/spirv/tri.vert.spv"));
pub const tri_frag_spv: []align(4) const u8 = @alignCast(4, @embedFile("shaders/spirv/tri.frag.spv"));