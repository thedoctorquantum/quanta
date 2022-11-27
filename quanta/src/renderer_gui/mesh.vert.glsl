#version 450 
#extension GL_EXT_scalar_block_layout : enable

struct Vertex 
{
    vec2 position;
    vec2 uv;
    uint color;
};

layout(binding = 0, scalar) restrict readonly buffer Vertices
{
    Vertex vertices[];
};

layout(push_constant) uniform PushConstants
{
    mat4 projection;
    uint texture_index;
} push_constants;

out Out 
{
    vec2 uv;
    vec4 color;
} out_data;

void main() 
{
    Vertex vertex = vertices[gl_VertexIndex];

    out_data.uv = vertex.uv;
    out_data.color = unpackUnorm4x8(vertex.color);
    out_data.color.r = pow(out_data.color.r, 2.2);
    out_data.color.g = pow(out_data.color.g, 2.2);
    out_data.color.b = pow(out_data.color.b, 2.2);

    gl_Position = push_constants.projection * vec4(vertex.position, 0, 1);
    gl_Position.y = -gl_Position.y;
}