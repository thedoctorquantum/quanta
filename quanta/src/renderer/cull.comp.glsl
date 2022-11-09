
#define f32 float
#define u32 uint
#define i32 int

layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 1, scalar) restrict readonly buffer Transforms
{
    mat4x3 transforms[];
};

layout(set = 0, binding = 5, scalar) restrict readonly buffer MeshIndices
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

layout(set = 0, binding = 6, scalar) restrict readonly buffer Meshes
{
    Mesh meshes[];
};

layout(set = 0, binding = 7, scalar) restrict readonly buffer MeshLods
{
    MeshLod mesh_lods[];
};

struct DrawIndexedIndirectCommand
{
    u32 index_count,
    u32 instance_count,
    u32 first_index,
    i32 vertex_offset,
    u32 first_instance, 
};

layout(set = 0, binding = 8, scalar) restrict writeonly buffer DrawCommands
{
    DrawIndexedIndirectCommand draw_commands[];
};

void main() 
{
    
}