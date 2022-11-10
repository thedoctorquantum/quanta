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

layout(set = 0, binding = 1, scalar) restrict readonly buffer MeshIndices
{
    u32 mesh_indices[];
};

struct Mesh 
{
    u32 lod_begin;
    u32 lod_count;
};

struct MeshLod 
{
    u32 vertex_offset;
    u32 vertex_start;
    u32 index_offset;
    u32 index_count;
};

layout(set = 0, binding = 2, scalar) restrict readonly buffer Meshes
{
    Mesh meshes[];
};

layout(set = 0, binding = 3, scalar) restrict readonly buffer MeshLods
{
    MeshLod mesh_lods[];
};

struct DrawIndexedIndirectCommand
{
    u32 index_count;
    u32 instance_count;
    u32 first_index;
    i32 vertex_offset;
    u32 first_instance; 
};

layout(set = 0, binding = 4, scalar) restrict writeonly buffer DrawCommands
{
    DrawIndexedIndirectCommand draw_commands[];
};

layout(set = 0, binding = 5) buffer DrawCommandCount
{
	uint draw_command_count;
};

void main() 
{
    uint di = gl_GlobalInvocationID.x;

	if (di >= draw_commands.length())
		return;

    if (di < 20)
    {
        u32 index = atomicAdd(draw_command_count, 1);

        draw_commands[index].instance_count = 1;
    }
    else 
    {
        draw_commands[di].instance_count = 0;
    }
}