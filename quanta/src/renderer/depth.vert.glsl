#version 450
#extension GL_EXT_scalar_block_layout : enable

struct Vertex 
{
    vec3 position;
    uint color;
    vec2 uv;
};

layout(push_constant) uniform Constants
{
    mat4 view_projection;
} constants;

layout(set = 0, binding = 0, scalar) readonly buffer Transforms
{
    mat3 transforms[];
};

layout(set = 0, binding = 1, scalar) readonly buffer VertexPositions
{
    vec3 vertex_positions[];
};

void main() 
{
    gl_Position = vertex_positions[gl_VertexIndex];
}