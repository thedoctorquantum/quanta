#version 450
#extension GL_EXT_scalar_block_layout : enable
#extension GL_EXT_nonuniform_qualifier : enable

#define u32 uint

struct AmbientLight 
{
    uint diffuse;
};

struct DirectionalLight 
{
    vec3 direction;
    uint diffuse;
};

struct PointLight 
{
    vec3 position;
    float intensity;
    uint diffuse;
};

layout(push_constant, scalar) uniform Constants
{
    mat4 view_projection;
    u32 point_light_count;
    vec3 view_position;
    AmbientLight ambient_light;
    DirectionalLight directional_light;
    bool use_directional_light;
} constants;

in Out
{
    flat uint material_index;
    flat uint primitive_index;
    vec3 position;
    vec3 normal;
    vec4 color;
    vec2 uv;
} in_data;

out vec4 output_color;

struct Material
{
    uint albedo_index;
    uint albedo_color;
};

layout(binding = 5, scalar) restrict readonly buffer Materials
{
    Material materials[];
};

layout(binding = 6) uniform sampler2D samplers[16000];

layout(binding = 7, scalar) restrict readonly buffer PointLights 
{
    PointLight point_lights[];
};

vec4 directionalLightContribution(DirectionalLight directional_light, vec3 normal, vec3 position, vec3 view_direction) 
{
    vec4 light_color = unpackUnorm4x8(directional_light.diffuse);

    vec3 light_direction = normalize(-directional_light.direction);
    float diffuse_factor = max(dot(normal, light_direction), 0);

    return light_color * diffuse_factor; 
}

vec4 pointLightContribution(PointLight point_light, vec3 normal, vec3 position, vec3 view_direction) 
{
    vec4 light_color = unpackUnorm4x8(point_light.diffuse);

    vec3 light_direction = normalize(point_light.position - position);
    float diffuse_factor = max(dot(normal, light_direction), 0);

    float light_distance = distance(position, point_light.position);
    float attenuation = point_light.intensity / (light_distance * light_distance);

    return light_color * diffuse_factor * attenuation; 
}

void main() 
{
    Material material = materials[in_data.material_index];

    vec3 view_direction = normalize(constants.view_position - in_data.position);

    vec4 albedo = in_data.color * unpackUnorm4x8(material.albedo_color);

    if (material.albedo_index != 0)
    {
        albedo *= texture(samplers[nonuniformEXT(material.albedo_index)], in_data.uv);
    }

    vec4 ambient_light = unpackUnorm4x8(constants.ambient_light.diffuse); 

    vec4 directional_light_color = vec4(0);

    if (constants.use_directional_light)
    {
        directional_light_color = directionalLightContribution(constants.directional_light, in_data.normal, in_data.position, constants.view_position);
    }

    vec4 point_light_color = vec4(0);

    uint point_light_count = constants.point_light_count;

    {
        uint i = 0;

        while (i < point_light_count)
        {
            PointLight point_light = point_lights[i];

            point_light_color += pointLightContribution(point_light, in_data.normal, in_data.position, constants.view_position);

            i += 1;
        }
    }

    output_color = albedo * (ambient_light + directional_light_color + point_light_color);
    // output_color = vec4(in_data.normal, 1);
    // output_color = vec4(in_data.uv, vec2(0, 1));
}