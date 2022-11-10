#version 450
#extension GL_EXT_scalar_block_layout : enable
#extension GL_ARB_shader_draw_parameters : enable

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

layout(set = 0, binding = 2, scalar) restrict readonly buffer MaterialIndicies
{
    uint material_indices[];
};

layout(location = 0) out Out
{
    flat uint material_index;
    flat uint instance_index;
    vec4 color;
    vec2 uv;
} out_data;

void main() 
{
    Vertex vertex = vertices[gl_VertexIndex]; 
    mat4 transform = mat4(transforms[gl_InstanceIndex]);

    out_data.color = unpackUnorm4x8(vertex.color);
    out_data.uv = vertex.uv;
    out_data.material_index = material_indices[gl_InstanceIndex]; 
    out_data.instance_index = gl_InstanceIndex;

    gl_Position = constants.view_projection * transform * vec4(vertex.position, 1.0);
}
