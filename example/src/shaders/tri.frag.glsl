#version 450

layout(location = 0) in Out
{
    vec4 fragment_color;
    vec2 uv;
} in_data;

layout(location = 0) out vec4 output_color;

layout(set = 0, binding = 1) uniform sampler2D albedo_sampler;

void main() 
{
    output_color = in_data.fragment_color * texture(albedo_sampler, in_data.uv);
}