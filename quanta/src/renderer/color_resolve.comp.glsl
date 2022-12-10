#version 450

layout(local_size_x_id = 0, local_size_y_id = 1, local_size_z_id = 2) in;

layout(rgba16f, binding = 0) uniform restrict readonly image2D read_target;
layout(rgba8, binding = 1) uniform restrict writeonly image2D write_target;

void main() 
{
    ivec2 target_size = imageSize(read_target);

    if (!(gl_GlobalInvocationID.x < target_size.x && gl_GlobalInvocationID.y < target_size.y))
    {
        return;
    }

    ivec2 position = ivec2(gl_GlobalInvocationID.xy);

    vec4 pixel = imageLoad(read_target, position);

    float gamma = 2.2;
    float exposure = 10;

    pixel.rgb = vec3(1.0) - exp(-pixel.rgb * exposure);
    pixel.rgb = pow(pixel.rgb, vec3(1.0 / gamma));

    imageStore(write_target, position, pixel);
}