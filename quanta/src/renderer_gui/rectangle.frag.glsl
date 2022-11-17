#version 450
#extension GL_EXT_scalar_block_layout : enable
#extension GL_EXT_nonuniform_qualifier : enable

layout(location = 0) in Out
{
    vec4 color;
} in_data;

layout(location = 0) out vec4 output_color;

layout(set = 0, binding = 1) uniform sampler2D samplers[4096];

void main() 
{
    output_color = in_data.color;
}