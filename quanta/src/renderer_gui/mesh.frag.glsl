#version 450 
#extension GL_EXT_nonuniform_qualifier : enable

in Out 
{
    vec2 uv;
    vec4 color;
} in_data;

out vec4 out_color;

layout(binding = 1) uniform sampler2D textures[2048];

layout(push_constant) uniform PushConstants
{
    mat4 projection;
    uint texture_index;
} push_constants;

void main() 
{   
    vec4 texture_sample;

    if (push_constants.texture_index != 0)
    {
        texture_sample = texture(textures[nonuniformEXT(push_constants.texture_index - 1)], in_data.uv);
    }
    else 
    {
        texture_sample = vec4(1);
    }

    out_color = in_data.color * texture_sample;
}