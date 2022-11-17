#version 450
#extension GL_EXT_scalar_block_layout : enable
#extension GL_ARB_shader_draw_parameters : enable
#extension GL_EXT_shader_16bit_storage : enable
#extension GL_EXT_shader_explicit_arithmetic_types_int16 : enable

#define u16 uint16_t 
#define u32 uint 

#define f32 float

struct Rectangle
{
    u16 x;
    u16 y;
    u16 width;
    u16 height;
    u32 color;
};

layout(set = 0, binding = 0, scalar) restrict readonly buffer Rectangles
{
    Rectangle rectangles[];
};

vec3 vertex_positions[6] = vec3[6](
    vec3(0, 0, 0),
    vec3(0, 0, 0),
    vec3(0, 0, 0),
    vec3(0, 0, 0),
    vec3(0, 0, 0),
    vec3(0, 0, 0)
); 

layout(push_constant) uniform block 
{
    f32 render_target_width;
    f32 render_target_height;
};

layout(location = 0) out Out
{
    vec4 color;
} out_data;

void main() 
{
    //Each rectangle will be rendered as 2 triangles
    u32 rectangle_index = gl_VertexIndex / 6;
    Rectangle rectangle = rectangles[rectangle_index];

    vec3 vertex_position = vertex_positions[gl_VertexIndex];

    u32 rectangle_x = rectangle.x; 
    u32 rectangle_y = rectangle.y;

    u32 rectangle_width = rectangle.width; 
    u32 rectangle_height = rectangle.height;

    vertex_position += vec3(rectangle_x, rectangle_y, 0) / render_target_width;
    vertex_position *= vec3(rectangle_width, rectangle_height, 0) / render_target_height;

    out_data.color = unpackUnorm4x8(rectangle.color);

    gl_Position = vec4(vertex_position, 1);
}