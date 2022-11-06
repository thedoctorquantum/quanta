#version 450
#extension GL_EXT_scalar_block_layout : enable

layout(push_constant) uniform Constants
{
    vec3 position;
} constants;

struct Vertex 
{
    vec3 position;
    vec3 normal;
    uint color;
    vec2 uv;
};

layout(set = 0, binding = 0, scalar) readonly buffer Vertices
{
    Vertex vertices[];
};

layout(location = 0) out Out
{
    vec4 fragment_color;
    vec2 uv;
} out_data;

void main() 
{
    Vertex vertex = vertices[gl_VertexIndex]; 

    out_data.fragment_color = unpackUnorm4x8(vertex.color);
    out_data.uv = vertex.uv;

    gl_Position = vec4(constants.position + vertex.position, 1.0);
}
