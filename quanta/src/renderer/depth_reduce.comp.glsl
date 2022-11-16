#version 450

layout(local_size_x_id = 0, local_size_y_id = 1, local_size_z_id = 2) in;

layout(binding = 0, r32f) uniform writeonly image2D out_image;
layout(binding = 1) uniform sampler2D in_image;

layout(push_constant) uniform block
{
	vec2 image_size;
};

void main()
{
	uvec2 pos = gl_GlobalInvocationID.xy;

	// Sampler is set up to do min reduction, so this computes the minimum depth of a 2x2 texel quad
	float depth = texture(in_image, (vec2(pos) + vec2(0.5)) / imageSize).x;

	imageStore(out_image, ivec2(pos), vec4(depth));
}