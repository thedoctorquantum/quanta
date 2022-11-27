#version 450

in Out
{
    vec3 uv;
} in_data;

out vec4 out_color;

layout(binding = 0) uniform samplerCube environment_sampler;

void main() 
{
    // out_color = vec4(0, 1, 0, 1);
    out_color = texture(environment_sampler, in_data.uv);
}