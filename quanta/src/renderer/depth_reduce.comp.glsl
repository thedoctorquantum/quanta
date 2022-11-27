#version 450
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x_id = 0, local_size_y_id = 1, local_size_z_id = 2) in;

layout(binding = 0, r32f) uniform writeonly image2D out_images[16];
layout(binding = 1) uniform sampler2D in_images[16];

layout(push_constant, scalar) uniform block
{
	vec2 image_size;
	uint image_index;
};

void main()
{
	uvec2 pos = gl_GlobalInvocationID.xy;

	// Sampler is set up to do min reduction, so this computes the minimum depth of a 2x2 texel quad
	float depth = texture(in_images[image_index], (vec2(pos) + vec2(0.5)) / image_size).x;

	imageStore(out_images[image_index], ivec2(pos), vec4(depth));
}