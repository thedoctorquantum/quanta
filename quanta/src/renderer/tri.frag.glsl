#version 450
#extension GL_EXT_scalar_block_layout : enable
#extension GL_EXT_nonuniform_qualifier : enable

#include "math.glsl"

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
    // uint metalness_index;
    // float metalness;
    // uint roughness_index;
    // float roughness;
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

float distributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float n_dot_h = max(dot(N, H), 0.0);
    float n_dot_h2 = n_dot_h * n_dot_h;
	
    float num = a2;
    float denom = n_dot_h2 * (a2 - 1.0) + 1.0;
    denom = PI * denom * denom;
	
    return num / denom;
}

float geometrySchlickGGX(float n_dot_v, float roughness)
{
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;

    float num = n_dot_v;
    float denom = n_dot_v * (1.0 - k) + k;
	
    return num / denom;
}

float geometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = geometrySchlickGGX(NdotV, roughness);
    float ggx1 = geometrySchlickGGX(NdotL, roughness);
	
    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cos_theta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0);
}  

vec4 directionalLightContribution(DirectionalLight directional_light, vec3 normal, vec3 position, vec3 view_direction) 
{
    vec4 light_color = unpackUnorm4x8(directional_light.diffuse);

    vec3 light_direction = normalize(-directional_light.direction);
    float diffuse_factor = max(dot(normal, light_direction), 0);

    return light_color * diffuse_factor; 
}

vec4 pointLightContribution(
    vec4 albedo,
    vec3 F0,
    PointLight point_light, 
    vec3 normal, 
    vec3 position, 
    vec3 view_direction
) 
{
    //material params
    float roughness = 0.5;
    float metallic = 0.8;

    vec4 light_color = unpackUnorm4x8(point_light.diffuse);

    vec3 light_direction = normalize(point_light.position - position);
    vec3 half_direction = normalize(view_direction + light_direction);
    float light_distance = distance(position, point_light.position);
    float attenuation = point_light.intensity / (light_distance * light_distance);
    vec3 radiance = vec3(light_color) * attenuation;

    float NDF = distributionGGX(normal, half_direction, roughness);        
    float G = geometrySmith(normal, view_direction, light_direction, roughness);      
    vec3 F = fresnelSchlick(max(dot(half_direction, view_direction), 0.0), F0);       

    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - metallic;	

    float n_dot_l = max(dot(normal, light_direction), 0.0);

    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(normal, view_direction), 0.0) * n_dot_l + 0.0001;
    vec3 specular = numerator / denominator;  

    // float diffuse_factor = max(dot(normal, light_direction), 0);
    // return diffuse_factor * radiance; 
    return vec4((kD * albedo.rgb / PI + specular) * radiance * n_dot_l, 0); 
}

void main() 
{
    Material material = materials[in_data.material_index];

    vec3 view_direction = normalize(constants.view_position - in_data.position);

    vec4 albedo = in_data.color * unpackUnorm4x8(material.albedo_color);
    float roughness = 0.5;
    float metallic = 0.8;

    if (material.albedo_index != 0)
    {
        albedo *= texture(samplers[nonuniformEXT(material.albedo_index)], in_data.uv);
    }

    vec4 ambient_light = unpackUnorm4x8(constants.ambient_light.diffuse); 

    vec4 light_color = vec4(0);

    vec3 F0 = vec3(0.04); 
    F0 = mix(F0, vec3(albedo), metallic);

    if (constants.use_directional_light)
    {
        light_color = directionalLightContribution(constants.directional_light, in_data.normal, in_data.position, constants.view_position);
    }

    uint point_light_count = constants.point_light_count;

    {
        uint i = 0;

        while (i < point_light_count)
        {
            PointLight point_light = point_lights[i];

            light_color += pointLightContribution(albedo, F0, point_light, in_data.normal, in_data.position, view_direction);

            i += 1;
        }
    }

    // output_color = albedo * (ambient_light + light_color);
    vec4 ambient = ambient_light * albedo;
    output_color = (ambient + vec4(vec3(light_color), 0));

    if (false)
    {
        output_color.xyz = output_color.xyz / (output_color.xyz + vec3(1));
        output_color.xyz = pow(output_color.xyz, vec3(1 / 2.2));
    }
}