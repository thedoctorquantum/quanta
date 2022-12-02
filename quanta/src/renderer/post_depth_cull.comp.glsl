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
    vec3 bounding_box_center;
    vec3 bounding_box_extents;
};

layout(set = 0, binding = 1, scalar) restrict readonly buffer Meshes
{
    Mesh meshes[];
};

layout(binding = 2) uniform sampler2D depth_pyramid;

struct DrawIndexedIndirectCommand
{
    u32 index_count;
    u32 instance_count;
    u32 first_index;
    u32 vertex_offset;
    u32 first_instance; 
    u32 instance_index;
};

layout(set = 0, binding = 3, scalar) restrict buffer DrawCommands
{
    DrawIndexedIndirectCommand draw_commands[];
};

layout(set = 0, binding = 4, scalar) restrict buffer DrawCommandCount
{
	u32 pre_depth_draw_command_count;
	u32 post_depth_draw_command_count;
};

layout(push_constant) uniform PushConstants
{
    u32 post_depth_draw_command_offset;
};

void main()
{
    u32 read_draw_index = gl_GlobalInvocationID.x;

	if (read_draw_index >= pre_depth_draw_command_count)
    {
		return;
    }

    bool visible = true;

    if (visible)
    {
        u32 write_draw_index = post_depth_draw_command_offset + atomicAdd(post_depth_draw_command_count, 1);

        draw_commands[write_draw_index] = draw_commands[read_draw_index];
    }
}
