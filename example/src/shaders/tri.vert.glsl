#version 450

layout(push_constant) uniform Constants
{
    vec3 position;
} constants;

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_color;

layout(location = 0) out Out
{
    vec3 fragment_color;
} out_data;

void main() 
{
    out_data.fragment_color = in_color;

    gl_Position = vec4(constants.position + in_position, 1.0);
}
