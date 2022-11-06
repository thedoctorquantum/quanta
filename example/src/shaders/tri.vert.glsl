#version 450

layout(push_constant) uniform Constants
{
    vec3 position;
} constants;

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_color;
layout(location = 2) in vec2 in_uv;

layout(location = 0) out Out
{
    vec3 fragment_color;
    vec2 uv;
} out_data;

void main() 
{
    out_data.fragment_color = in_color;
    out_data.uv = in_uv;

    gl_Position = vec4(constants.position + in_position, 1.0);
}
