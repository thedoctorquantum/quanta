#version 450
#extension GL_EXT_scalar_block_layout : enable
#extension GL_EXT_nonuniform_qualifier : enable

#define u32 uint
#define f32 float

layout(location = 0) in Out
{
    flat vec4 color;
    flat u32 x;
    flat u32 y;
    flat u32 height;
    flat u32 width;
    flat f32 border_radius;
} in_data;

layout(location = 0) out vec4 output_color;

layout(set = 0, binding = 1) uniform sampler2D samplers[4096];

void main() 
{
    vec2 pos = vec2(gl_FragCoord);

    vec2 edge_pos = vec2(in_data.x, in_data.y);
    vec2 circle_pos = edge_pos + in_data.border_radius;

    output_color = in_data.color;
    return;

    if (all(greaterThan(pos, circle_pos)))
    {
        output_color = in_data.color;
    }
    else 
    {
        float distance_from_edge = distance(pos, circle_pos);

        if (distance_from_edge < in_data.border_radius)
        {
            output_color = vec4(1, 1, 1, 1);
        }
        else 
        {
            discard;
        }
    }
}