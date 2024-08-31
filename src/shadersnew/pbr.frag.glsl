#version 430

#pragma combo DIRECT_LIGHT    0 1
// 0 is no ambient, 1 is flat ambient, 2 is ambient probe
#pragma combo AMBIENT_LIGHT   0 2
#pragma combo ENVMAP          0 1
#pragma combo FOG             0 1
#pragma combo ALPHA_TEST      0 1
#pragma combo HAS_SHADOW_SUNLIGHT 0 1
#pragma combo CLIPPING        0 1
#pragma combo LIGHTMAP        0 1

const float PI = 3.141592;

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common.inc.glsl"
#include "shadersnew/common_frag.inc.glsl"
#include "shadersnew/common_shadows_frag.inc.glsl"

uniform sampler2D albedo_sampler;
uniform sampler2D normal_sampler;
uniform sampler2D roughness_sampler;
uniform sampler2D metalness_sampler;
uniform sampler2D ao_sampler;
uniform sampler2D emission_sampler;
//uniform sampler2D emission_sampler;

vec4 scales;
#define roughness_scale (scales.x)
#define ao_scale (scales.y)
#define emission_scale (scales.z)
#define normal_scale (scales.w)

#if LIGHTMAP
in vec2 l_texcoord_lightmap;
uniform sampler2D lightmapTextureL0;
uniform sampler2D lightmapTextureL1y;
uniform sampler2D lightmapTextureL1z;
uniform sampler2D lightmapTextureL1x;
#endif

#if ENVMAP
uniform samplerCube cubemap_sampler;
uniform sampler2D specular_brdf_lut;
#endif

#if DIRECT_LIGHT
#define MAX_LIGHTS 4
uniform struct p3d_LightSourceParameters {
  vec4 color;
  vec4 position;
  vec4 direction;
  vec4 spotParams;
  vec3 attenuation;
} p3d_LightSource[MAX_LIGHTS];
layout(constant_id = 0) const int NUM_LIGHTS = 0;

#if HAS_SHADOW_SUNLIGHT
uniform sampler2DArrayShadow p3d_CascadeShadowMap;
uniform vec2 p3d_CascadeNearFar[4];
uniform vec4 shadowOffsetParams;
uniform sampler3D shadowOffsetTexture;
in vec4 l_cascadeCoords[4];
layout(constant_id = 6) const int NUM_CASCADES = 0;
#endif // HAS_SHADOW_SUNLIGHT

#else // DIRECT_LIGHT
#define NUM_LIGHTS 0
#endif // DIRECT_LIGHT

// Uniforms for volume tiled lighting.
uniform samplerBuffer p3d_StaticLightBuffer;
uniform samplerBuffer p3d_DynamicLightBuffer;
uniform isamplerBuffer p3d_LightListBuffer;
uniform vec2 p3d_LensNearFar;
uniform vec2 p3d_WindowSize;
uniform vec3 p3d_LightLensDiv;
uniform vec2 p3d_LightLensZScaleBias;
#include "shadersnew/common_clustered_lighting.inc.glsl"

#if AMBIENT_LIGHT == 1
// Flat ambient.
uniform struct {
  vec4 ambient;
} p3d_LightModel;
#elif AMBIENT_LIGHT == 2
// Ambient probe.
uniform vec3 ambientProbe[9];
#endif // AMBIENT_LIGHT

#if ALPHA_TEST
layout(constant_id = 7) const int ALPHA_TEST_MODE = M_none;
layout(constant_id = 8) const float ALPHA_TEST_REF = 0.0;
#endif // ALPHA_TEST

#if FOG
layout(constant_id = 9) const int FOG_MODE = FM_linear;
layout(constant_id = 13) const int BLEND_MODE = 0;
uniform struct p3d_FogParameters {
  vec4 color;
  float density;
  float end;
  float scale; // 1.0 / (end - start)
} p3d_Fog;
#endif

// Clip planes.
#if CLIPPING
uniform vec4 p3d_WorldClipPlane[4];
layout(constant_id = 10) const int NUM_CLIP_PLANES = 0;
#endif

layout(constant_id = 11) const bool BAKED_VERTEX_LIGHT = false;

vec3
ambientLookup(vec3 wnormal) {
#if LIGHTMAP
  vec3 sh[4];
  get_l1_lightmap_sample(lightmapTextureL0, lightmapTextureL1x,
                         lightmapTextureL1y, lightmapTextureL1z, l_texcoord_lightmap, sh);
  return eval_sh_l1(sh, wnormal);
#elif AMBIENT_LIGHT == 2
  return sample_l2_ambient_probe(ambientProbe, wnormal);

#elif AMBIENT_LIGHT == 1
  return p3d_LightModel.ambient.rgb;

#else
  if (BAKED_VERTEX_LIGHT) {
    return l_vertex_light;
  } else {
#if DIRECT_LIGHT
    return vec3(0.0);
#else
    return vec3(1.0);
#endif
  }

#endif
}

in vec4 l_world_position;
in vec3 l_world_normal;
in vec2 l_texcoord;
in vec3 l_world_tangent;
in vec3 l_world_binormal;
in vec3 l_world_vertex_to_eye;
in vec4 l_vertex_color;
in vec3 l_vertex_light;
in vec3 l_eye_pos;

out vec4 o_color;

// GGX/Towbridge-Reitz normal distribution function.
// Uses Disney's reparametrization of alpha = roughness^2.
float ndfGGX(float cosLh, float roughness)
{
	float alpha   = roughness * roughness;
	float alphaSq = alpha * alpha;

	float denom = (cosLh * cosLh) * (alphaSq - 1.0) + 1.0;
	return alphaSq / (PI * denom * denom);
}

// Single term for separable Schlick-GGX below.
float gaSchlickG1(float cosTheta, float k)
{
	return cosTheta / (cosTheta * (1.0 - k) + k);
}

// Schlick-GGX approximation of geometric attenuation function using Smith's method.
float gaSchlickGGX(float cosLi, float cosLo, float roughness)
{
	float r = roughness + 1.0;
	float k = (r * r) / 8.0; // Epic suggests using this roughness remapping for analytic lights.
	return gaSchlickG1(cosLi, k) * gaSchlickG1(cosLo, k);
}

// Shlick's approximation of the Fresnel factor.
vec3 fresnelSchlick(vec3 F0, float cosTheta)
{
	return F0 + (vec3(1.0) - F0) * pow(1.0 - cosTheta, 5.0);
}

//#if DIRECT_LIGHT

// Accumulates lighting for the given light index.
void doLight(in ClusterLightData light, inout vec3 directLighting, float roughness, float metalness, vec3 albedo, vec3 N, vec3 Lo, vec3 F0, float cosLo, float ao, vec3 worldPos) {

  vec3 lightColor = light.color;
  vec3 lightPos = light.pos;
  vec3 lightDir = normalize(light.direction);
  vec3 attenParams = vec3(light.constant_atten, light.linear_atten, light.quadratic_atten);
  vec4 spotParams = vec4(light.spot_exponent, light.spot_stopdot, light.spot_stopdot2, light.spot_oodot);
  float lightDist = 0.0;
  float lightAtten = 1.0;

  float shadowFactor = 1.0;

  float cosLi;

  vec3 Li;
  if (light.type == LIGHT_TYPE_DIRECTIONAL) {
    Li = lightDir;

    cosLi = max(0.0, dot(N, Li));


#if HAS_SHADOW_SUNLIGHT
    if (cosLi > 0.0) {
      GetSunShadow(shadowFactor, p3d_CascadeShadowMap, l_cascadeCoords, cosLi, NUM_CASCADES, shadowOffsetTexture,
        shadowOffsetParams.x, shadowOffsetParams.y, shadowOffsetParams.z, gl_FragCoord.xy, shadowOffsetParams.w, p3d_CascadeNearFar);
    } else {
      shadowFactor = 0.0;
    }
#endif


  } else {
    Li = lightPos - worldPos;
    lightDist = max(0.00001, length(Li));
    Li = normalize(Li);

    cosLi = max(0.0, dot(N, Li));

    //if (fNdotL > 0.0) {
      lightAtten = 1.0 / (attenParams.x + attenParams.y * lightDist + attenParams.z * (lightDist * lightDist));
      lightAtten *= (light.atten_radius > 0.0) ? (1.0 - (lightDist / light.atten_radius)) : 1.0;
      lightAtten = max(0.0, lightAtten);

      if (light.type == LIGHT_TYPE_SPOT) {
        // Spotlight cone attenuation.
        float cosTheta = clamp(dot(Li, -lightDir), 0, 1);
        float spotAtten = (cosTheta - spotParams.z) * spotParams.w;
        spotAtten = max(0.0001, spotAtten);
        spotAtten = pow(spotAtten, spotParams.x);
        spotAtten = clamp(spotAtten, 0, 1);
        lightAtten *= spotAtten;
      }
    //}
  }

  lightAtten *= shadowFactor;

  // Half vector between frag to light and frag to eye.
  vec3 Lh = normalize(Li + Lo);

  float cosLh = max(0.0, dot(N, Lh));

  vec3 F = fresnelSchlick(F0, max(0.0, dot(Lh, Lo)));
  float D = ndfGGX(cosLh, roughness);
  float G = gaSchlickGGX(cosLi, cosLo, roughness);

  vec3 kd = mix(vec3(1.0) - F, vec3(0.0), metalness);

  vec3 diffuse_brdf = kd * albedo;
  vec3 specular_brdf = (F * D * G) / max(0.00001, 4.0 * cosLi * cosLo);

  directLighting += (diffuse_brdf + specular_brdf) * lightColor * lightAtten * cosLi;
}

void doLighting(inout vec3 directLighting, float roughness, float metalness, vec3 albedo, vec3 N, vec3 Lo, vec3 F0, float cosLo, float ao, vec3 worldPos, int numLights) {
  // Start diffuse at ambient color.

#if DIRECT_LIGHT
  for (int i = 0; i < numLights; i++) {
    ClusterLightData light;
    light.color = p3d_LightSource[i].color.rgb;
    light.pos = p3d_LightSource[i].position.xyz;
    light.direction = p3d_LightSource[i].direction.xyz;
    light.constant_atten = p3d_LightSource[i].attenuation.x;
    light.linear_atten = p3d_LightSource[i].attenuation.y;
    light.quadratic_atten = p3d_LightSource[i].attenuation.z;
    light.atten_radius = 0.0;
    light.spot_exponent = p3d_LightSource[i].spotParams.x;
    light.spot_stopdot = p3d_LightSource[i].spotParams.y;
    light.spot_stopdot2 = p3d_LightSource[i].spotParams.z;
    light.spot_oodot = p3d_LightSource[i].spotParams.w;
    if (p3d_LightSource[i].color.w == 1.0) {
      light.type = LIGHT_TYPE_DIRECTIONAL;
    } else if (p3d_LightSource[i].direction.w == 1.0) {
      light.type = LIGHT_TYPE_SPOT;
    } else {
      light.type = LIGHT_TYPE_POINT;
    }
    doLight(light, directLighting, roughness, metalness, albedo, N, Lo, F0, cosLo, ao, worldPos);
  }
#endif

  OPEN_ITERATE_CLUSTERED_LIGHTS()
    fetch_cluster_light(light_index, p3d_StaticLightBuffer, p3d_DynamicLightBuffer, light);
    doLight(light, directLighting, roughness, metalness, albedo, N, Lo, F0, cosLo, ao, worldPos);
  CLOSE_ITERATE_CLUSTERED_LIGHTS()
}

//#endif // DIRECT_LIGHT

void
main() {
#if CLIPPING
  int clip_plane_count = min(4, NUM_CLIP_PLANES);
  for (int i = 0; i < clip_plane_count; ++i) {
    if (dot(p3d_WorldClipPlane[i], l_world_position) < 0.0) {
      discard;
    }
  }
#endif

  vec4 albedo = texture(albedo_sampler, l_texcoord);
  albedo *= l_vertex_color;
#if ALPHA_TEST
  if (!do_alpha_test(alpha.a, ALPHA_TEST_MODE, ALPHA_TEST_REF)) {
    discard;
  }
#endif
  float roughness = texture(roughness_sampler, l_texcoord).r * roughness_scale;
  float metalness = texture(metalness_sampler, l_texcoord).r;
  float ao = min(1.0, texture(ao_sampler, l_texcoord).r / max(0.0001, ao_scale));

  vec3 Lo = normalize(l_world_vertex_to_eye);

  vec3 N = 2.0 * texture(normal_sampler, l_texcoord).rgb - 1.0;
  N.xy *= normal_scale;
  N = normalize(N);
  // Get a new world-space normal from the normal map normal.
  N = normalize(normalize(l_world_tangent) * N.x + normalize(l_world_binormal) * N.y + normalize(l_world_normal) * N.z);

  float cosLoUnnorm = dot(N, Lo);
  float cosLo = max(0.0, cosLoUnnorm);

  vec3 Lr = 2.0 * cosLoUnnorm * N - Lo;

  vec3 F0 = mix(vec3(0.04), albedo.rgb, metalness);

  vec3 directLighting = vec3(0.0);
//#if DIRECT_LIGHT && NUM_LIGHTS > 0
  doLighting(directLighting, roughness, metalness, albedo.rgb, N, Lo, F0, cosLo, ao, l_world_position.xyz, NUM_LIGHTS);
//#endif
  vec3 ambientLighting = vec3(0.0);

  vec3 irradiance = ambientLookup(N);
  vec3 F = fresnelSchlick(F0, cosLo);
  vec3 kd = mix(vec3(1.0) - F, vec3(0.0), metalness);
  vec3 diffuseIBL = kd * albedo.rgb * irradiance * ao;
#if ENVMAP
  int specular_levels = textureQueryLevels(cubemap_sampler);
  vec3 specular_irradiance = textureLod(cubemap_sampler, Lr, roughness * specular_levels).rgb;
  vec2 specular_brdf = texture(specular_brdf_lut, vec2(cosLo, roughness)).rg;
  vec3 specularIBL = (F0 * specular_brdf.x + specular_brdf.y) * specular_irradiance;
#else
  vec3 specularIBL = vec3(0.0);
#endif

  ambientLighting += diffuseIBL + specularIBL;

  vec3 emission = texture(emission_sampler, l_texcoord).rgb * emission_scale;

  o_color = vec4(directLighting + ambientLighting + emission, albedo.a);

#if FOG
  vec3 fog_color;
  if (BLEND_MODE == 2) {
    // Additive blending, we need black fog.
    fog_color = vec3(0.0);
  } else if (BLEND_MODE == 1) {
    // Modulate blending, we need gray fog.
    fog_color = vec3(0.5);
  } else {
    // Gamma-correct the fog color.
    fog_color = pow(p3d_Fog.color.rgb, vec3(2.2));
  }
  o_color.rgb = do_fog(o_color.rgb, l_eye_pos, fog_color,
                       p3d_Fog.density, p3d_Fog.end, p3d_Fog.scale,
                       FOG_MODE);
#endif
}
