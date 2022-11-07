#version 450
#extension GL_EXT_scalar_block_layout : enable
#extension GL_ARB_shader_draw_parameters : enable

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

layout(set = 0, binding = 1, scalar) readonly buffer Transforms
{
    mat4 transforms[];
};

layout(set = 0, binding = 2, scalar) readonly buffer MaterialIndicies
{
    uint material_indices[];
};

layout(location = 0) out Out
{
    uint material_index;
    vec4 fragment_color;
    vec2 uv;
} out_data;

void main() 
{
    Vertex vertex = vertices[gl_VertexIndex]; 
    mat4 transform = transforms[gl_DrawIDARB];

    out_data.fragment_color = unpackUnorm4x8(vertex.color);
    out_data.uv = vertex.uv;
    out_data.material_index = material_indices[gl_DrawIDARB]; 

    gl_Position = transform * vec4(vertex.position, 1.0);
}
