#version 450

layout(location = 0) in Out
{
    vec3 fragment_color;
    vec2 uv;
} in_data;

layout(location = 0) out vec4 output_color;

layout (set = 0, binding = 0) uniform sampler2D albedo_sampler;

void main() 
{
    output_color = vec4(in_data.fragment_color, 1) * texture(albedo_sampler, in_data.uv);
}