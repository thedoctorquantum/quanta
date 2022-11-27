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

layout(push_constant, scalar) uniform PushConstants
{
    u32 draw_count;

    //not very memory efficient 
    vec4 near_face;
    vec4 far_face;
    vec4 right_face;
    vec4 left_face;
    vec4 top_face;
    vec4 bottom_face;
};

bool isOnOrForwardPlane(vec4 plan, vec3 center, vec3 extents)
{
    f32 r = extents.x * abs(plan.x) + 
            extents.y * abs(plan.y) +
            extents.z * abs(plan.z);

    return -r <= (dot(plan.xyz, center) - plan.z);
}

bool isOnFrustum(mat4 transform, vec3 center, vec3 extents) 
{
    vec3 global_center = vec3(transform * vec4(center, 1));

    vec3 right = vec3(transform[0]) * extents.x;
    vec3 up = vec3(transform[1]) * extents.y;
    vec3 forward = vec3(-transform[2]) * extents.z;

    f32 newIi = 
        abs(dot(vec3(1, 0, 0), right)) +
        abs(dot(vec3(1, 0, 0), up)) +
        abs(dot(vec3(1, 0, 0), forward));

    f32 newIj = 
        abs(dot(vec3(0, 1, 0), right)) +
        abs(dot(vec3(0, 1, 0), up)) +
        abs(dot(vec3(0, 1, 0), forward));
    
    f32 newIk = 
        abs(dot(vec3(0, 0, 1), right)) +
        abs(dot(vec3(0, 0, 1), up)) +
        abs(dot(vec3(0, 0, 1), forward));
    
    vec3 global_extents = vec3(newIi, newIj, newIk);

    return isOnOrForwardPlane(near_face, global_center, global_extents);
           isOnOrForwardPlane(far_face, global_center, global_extents) &&
           isOnOrForwardPlane(right_face, global_center, global_extents) &&
           isOnOrForwardPlane(left_face, global_center, global_extents) &&
           isOnOrForwardPlane(top_face, global_center, global_extents) &&
           isOnOrForwardPlane(bottom_face, global_center, global_extents);
}

void main() 
{
    u32 read_draw_index = gl_GlobalInvocationID.x;

	if (read_draw_index >= draw_count)
    {
		return;
    }

    InputDraw draw = input_draws[read_draw_index];
    Mesh mesh = meshes[draw.mesh_index];

    bool visible = true;

    visible = visible && isOnFrustum(mat4(transforms[draw.mesh_index]), mesh.bounding_box_center, mesh.bounding_box_extents);

    if (visible)
    {
        MeshLod mesh_lod = mesh_lods[mesh.lod_begin];

        u32 write_draw_index = atomicAdd(draw_command_count, 1);

        draw_commands[write_draw_index].first_index = mesh_lod.index_offset;
        draw_commands[write_draw_index].index_count = mesh_lod.index_count;
        draw_commands[write_draw_index].vertex_offset = mesh.vertex_offset;
        draw_commands[write_draw_index].first_instance = 0;
        draw_commands[write_draw_index].instance_count = 1;
        draw_commands[write_draw_index].instance_index = read_draw_index;
    }
}