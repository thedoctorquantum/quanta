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
    float intensity;
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
    uint albedo;
    uint metalness_index;
    float metalness;
    uint roughness_index;
    float roughness;
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

layout(binding = 8) uniform samplerCube environment_sampler;

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

//Bidirectional Scattering Distribution function for the surface
#if 0
vec4 bsdf(
    vec3 view_direction,
    vec3 light_direction,
    vec4 albedo,
    float roughness,
    float metallic,
    vec3 F0,
) 
{
    vec3 half_direction = normalize(view_direction + light_direction);
    float n_dot_l = max(dot(normal, light_direction), 0.0);

    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - metallic;	

    vec3 diffuse = kD * albedo.rgb / PI; 

    float NDF = distributionGGX(normal, half_direction, roughness);        
    float G = geometrySmith(normal, view_direction, light_direction, roughness);      
    vec3 F = fresnelSchlick(max(dot(half_direction, view_direction), 0.0), F0);       

    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(normal, view_direction), 0.0) * n_dot_l + 0.0001;
    vec3 specular = numerator / denominator;  

    return diffuse + specular;
}
#endif

vec4 directionalLightContribution(
    vec4 albedo,
    float roughness,
    float metallic,
    vec3 F0,
    DirectionalLight directional_light,
    vec3 normal, 
    vec3 position, 
    vec3 view_direction
) 
{
    vec4 light_color = unpackUnorm4x8(directional_light.diffuse);

    vec3 light_direction = normalize(-directional_light.direction);
    vec3 half_direction = normalize(view_direction + light_direction);
    vec3 radiance = vec3(light_color);

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

    return vec4((kD * albedo.rgb / PI + specular) * vec3(1) * n_dot_l * directional_light.intensity, 0); 
}

vec4 pointLightContribution(
    vec4 albedo,
    float roughness,
    float metallic,
    vec3 F0,
    PointLight point_light, 
    vec3 normal, 
    vec3 position, 
    vec3 view_direction
) 
{
    //point lights are spheres with a radius of 1cm 
    const float emitter_radius = 0.01;

    vec4 light_color = unpackUnorm4x8(point_light.diffuse);

    vec3 light_direction = normalize(point_light.position - position);
    vec3 half_direction = normalize(view_direction + light_direction);
    float light_distance = distance(position, point_light.position);
    float attenuation = point_light.intensity / max(light_distance * light_distance, emitter_radius * emitter_radius);
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

    return vec4((kD * albedo.rgb / PI + specular) * radiance * n_dot_l, 0); 
}

void main() 
{
    Material material = materials[in_data.material_index];

    vec3 view_direction = normalize(constants.view_position - in_data.position);

    vec4 albedo = in_data.color * unpackUnorm4x8(material.albedo);
    float roughness = material.roughness;
    float metallic = material.metalness;

    if (material.albedo_index != 0)
    {
        albedo *= texture(samplers[nonuniformEXT(material.albedo_index)], in_data.uv);
    }

    if (material.roughness_index != 0)
    {
        metallic *= texture(samplers[nonuniformEXT(material.roughness_index)], in_data.uv).r;
        roughness *= texture(samplers[nonuniformEXT(material.roughness_index)], in_data.uv).g;
    }

    vec4 ambient_light = unpackUnorm4x8(constants.ambient_light.diffuse); 

    vec4 light_color = vec4(0);

    vec3 F0 = vec3(0.04); 
    F0 = mix(F0, vec3(albedo), metallic);

    if (constants.use_directional_light)
    {
        light_color += directionalLightContribution(
                albedo,
                roughness,
                metallic, 
                F0, 
                constants.directional_light, 
                in_data.normal, 
                in_data.position, 
                view_direction
        );
    }

    uint point_light_count = constants.point_light_count;

    {
        uint i = 0;

        while (i < point_light_count)
        {
            PointLight point_light = point_lights[i];

            light_color += pointLightContribution(
                albedo,
                roughness,
                metallic, 
                F0, 
                point_light, 
                in_data.normal, 
                in_data.position, 
                view_direction
            );

            i += 1;
        }
    }

    vec4 ambient = ambient_light * albedo;

    output_color = ambient + vec4(vec3(light_color), 0);
}