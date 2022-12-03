#version 450
#extension GL_EXT_scalar_block_layout : enable
#extension GL_ARB_shader_draw_parameters : enable

#define u32 uint

layout(push_constant, scalar) uniform Constants
{
    mat4 view_projection;
    u32 point_light_count;
    vec3 view_position;
} constants;

struct Vertex 
{
    vec3 normal;
    uint color;
    vec2 uv;
};

layout(set = 0, binding = 0, scalar) restrict readonly buffer VertexPositions
{
    vec3 vertex_positions[];
};

layout(set = 0, binding = 1, scalar) restrict readonly buffer Vertices
{
    Vertex vertices[];
};

layout(set = 0, binding = 2, scalar) restrict readonly buffer Transforms
{
    mat4x3 transforms[];
};

layout(set = 0, binding = 3, scalar) restrict readonly buffer MaterialIndicies
{
    uint material_indices[];
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

layout(set = 0, binding = 4, scalar) restrict readonly buffer DrawCommands
{
    DrawIndexedIndirectCommand draw_commands[];
};

out Out
{
    flat uint material_index;
    flat uint primitive_index;
    vec3 position;
    vec3 normal;
    vec4 color;
    vec2 uv;
} out_data;

void main() 
{
    uint instance_index = draw_commands[gl_DrawIDARB].instance_index;
    
    Vertex vertex = vertices[gl_VertexIndex]; 
    mat4 transform = mat4(transforms[instance_index]);

    vec4 translation = transform * vec4(vertex_positions[gl_VertexIndex], 1.0);

    out_data.position = vec3(translation);
    out_data.color = unpackUnorm4x8(vertex.color);
    out_data.normal = vertex.normal;
    out_data.uv = vertex.uv;
    out_data.material_index = material_indices[instance_index]; 
    out_data.primitive_index = gl_VertexIndex / 3; 

    gl_Position = constants.view_projection * transform * vec4(vertex_positions[gl_VertexIndex], 1.0);
}
