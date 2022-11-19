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
    f32 border_radius;
};

layout(set = 0, binding = 0, scalar) restrict readonly buffer Rectangles
{
    Rectangle rectangles[];
};

vec3 vertex_positions[6] = vec3[6](
    vec3(-1.0, -1.0, 0),
    vec3(+1.0, -1.0, 0),
    vec3(-1.0, +1.0, 0),

    vec3(-1.0, +1.0, 0),
    vec3(+1.0, -1.0, 0),
    vec3(+1.0, +1.0, 0)
); 

layout(push_constant) uniform block 
{
    f32 render_target_width;
    f32 render_target_height;
    Rectangle rectangle;
} push_constants;

layout(location = 0) out Out
{
    flat vec4 color;
    flat u32 x;
    flat u32 y;
    flat u32 height;
    flat u32 width;
    flat f32 border_radius;
} out_data;

void main() 
{
    //Each rectangle will be rendered as 2 triangles
    // u32 rectangle_index = push_constants.rectangle_index + gl_InstanceIndex;
    // Rectangle rectangle = rectangles[rectangle_index];
    Rectangle rectangle = push_constants.rectangle;

    vec2 vertex_position = vec2(vertex_positions[gl_VertexIndex]);

    u32 rectangle_x = rectangle.x; 
    u32 rectangle_y = rectangle.y;

    u32 rectangle_width = rectangle.width; 
    u32 rectangle_height = rectangle.height;

    f32 scale_x = rectangle_width / push_constants.render_target_width;
    f32 scale_y = rectangle_height / push_constants.render_target_height;
    
    vec2 translation = vec2(rectangle_x / push_constants.render_target_width, rectangle_y / push_constants.render_target_height);

    vertex_position = ((1 + vertex_position) * vec2(scale_x, scale_y)) - 1;
    vertex_position += translation * 2;

    out_data.x = rectangle_x;
    out_data.y = rectangle_y;
    out_data.width = rectangle_width;
    out_data.height = rectangle_height;
    out_data.color = unpackUnorm4x8(rectangle.color);
    out_data.border_radius = rectangle.border_radius;

    gl_Position = vec4(vec3(vertex_position, 1), 1);
}