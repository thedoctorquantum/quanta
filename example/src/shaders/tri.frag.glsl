#version 450

layout(location = 0) in Out
{
    vec3 fragment_color;
} in_data;

layout(location = 0) out vec4 output_color;

void main() 
{
    output_color = vec4(in_data.fragment_color, 1) * 0.2;
}