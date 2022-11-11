#version 450
#extension GL_EXT_scalar_block_layout : enable

#define f64 double
#define f32 float
#define u32 uint
#define i32 int

layout(local_size_x_id = 0, local_size_y_id = 1, local_size_z_id = 2) in;

layout(set = 0, binding = 0, scalar) restrict readonly buffer Transforms
{
    mat4x3 transforms[];
};

struct Mesh 
{
    u32 vertex_offset;
    u32 vertex_start;
    u32 lod_begin;
    u32 lod_count;
};

struct MeshLod 
{
    u32 index_offset;
    u32 index_count;
};

layout(set = 0, binding = 1, scalar) restrict readonly buffer Meshes
{
    Mesh meshes[];
};

layout(set = 0, binding = 2, scalar) restrict readonly buffer MeshLods
{
    MeshLod mesh_lods[];
};

struct DrawIndexedIndirectCommand
{
    u32 index_count;
    u32 instance_count;
    u32 first_index;
    u32 vertex_offset;
    u32 first_instance; 
    u32 instance_index;
};

layout(set = 0, binding = 3, scalar) restrict writeonly buffer DrawCommands
{
    DrawIndexedIndirectCommand draw_commands[];
};

layout(set = 0, binding = 4) buffer DrawCommandCount
{
	u32 draw_command_count;
};

struct InputDraw 
{
    u32 mesh_index;
};

layout(set = 0, binding = 5, scalar) restrict readonly buffer InputDraws
{
    InputDraw input_draws[];
};

layout(push_constant) uniform PushConstants
{
    u32 draw_count;
};

void main() 
{
    u32 read_draw_index = gl_GlobalInvocationID.x;

	if (read_draw_index >= draw_count)
		return;

    InputDraw draw = input_draws[read_draw_index];
    Mesh mesh = meshes[draw.mesh_index];
    MeshLod mesh_lod = mesh_lods[mesh.lod_begin];

    bool visible = true;

    if (visible)
    {
        u32 write_draw_index = atomicAdd(draw_command_count, 1);

        draw_commands[write_draw_index].first_index = mesh_lod.index_offset / 4;
        draw_commands[write_draw_index].index_count = mesh_lod.index_count;
        draw_commands[write_draw_index].vertex_offset = mesh.vertex_offset / 36;
        draw_commands[write_draw_index].first_instance = 0;
        draw_commands[write_draw_index].instance_count = 1;
        draw_commands[write_draw_index].instance_index = read_draw_index;
    }
}