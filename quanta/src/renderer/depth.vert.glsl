#version 450
#extension GL_EXT_scalar_block_layout : enable
#extension GL_ARB_shader_draw_parameters : enable

#define u32 uint

layout(push_constant) uniform Constants
{
    mat4 view_projection;
} constants;

struct Vertex 
{
    vec3 position;
    vec3 normal;
    uint color;
    vec2 uv;
};

layout(set = 0, binding = 0, scalar) restrict readonly buffer Vertices
{
    Vertex vertices[];
};

layout(set = 0, binding = 1, scalar) restrict readonly buffer Transforms
{
    mat4x3 transforms[];
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

layout(set = 0, binding = 2, scalar) restrict readonly buffer DrawCommands
{
    DrawIndexedIndirectCommand draw_commands[];
};

void main() 
{
    uint instance_index = draw_commands[gl_DrawIDARB].instance_index;
    
    Vertex vertex = vertices[gl_VertexIndex]; 
    mat4 transform = mat4(transforms[instance_index]);

    gl_Position = constants.view_projection * transform * vec4(vertex.position, 1.0);
}
