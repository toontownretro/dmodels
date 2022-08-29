#version 430

#pragma combo ANIMATEDNORMALMAP 0 2
#pragma combo FOG 0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common.inc.glsl"

uniform sampler2DArray lightmapSampler;
uniform sampler2D reflectionSampler;
uniform sampler2D refractionSampler;

#if FOG
uniform sampler2D refractionDepthSampler;
uniform vec3 u_fogColor;
uniform vec2 u_fogRange;
uniform vec2 u_fogLensNearFar;
#define u_fogStart (u_fogRange.x)
#define u_fogEnd (u_fogRange.y)
#define u_fogNear (u_fogLensNearFar.x)
#define u_fogFar (u_fogLensNearFar.y)
#endif

uniform vec4 u_reflectRefractScale;
uniform vec3 u_reflectTint;
uniform vec3 u_refractTint;
uniform vec2 u_fresnelExponent;

#if ANIMATEDNORMALMAP
uniform sampler2DArray normalSampler;
uniform vec2 u_normalMapFPS;
uniform float osg_FrameTime;
#else
uniform sampler2D normalSampler;
#endif

in vec2 l_texcoord;
in vec2 l_texcoord_lightmap;
in vec4 l_proj_pos;
in vec4 l_reflectxy_refractyx;
in float l_w;
in vec3 l_world_normal;
in vec3 l_world_tangent;
in vec3 l_world_binormal;
in vec3 l_world_vertex_to_eye;
in vec3 l_eye_pos;

out vec4 o_color;

float
calc_dist(float depth, float near, float far) {
  return 2.0 * near * far / ( far + near - ( 2.0 * depth - 1.0 ) * ( far - near ) );
}

float
calc_fog_factor(float dist, float start, float end) {
  float scale = 1.0 / (end - start);
  return clamp(1.0 - ((end - dist) * scale), 0.0, 1.0);
}

void
main() {

#if ANIMATEDNORMALMAP
  int num_frames = textureSize(normalSampler, 0).z;
  float fframe = (osg_FrameTime * u_normalMapFPS.x);
  int frame = int(fframe) % num_frames;

#if ANIMATEDNORMALMAP == 2
  int next_frame = (frame + 1) % num_frames;
  float frac = fframe - int(fframe);

  vec4 norm_sample0 = texture(normalSampler, vec3(l_texcoord, frame));
  vec4 norm_sample1 = texture(normalSampler, vec3(l_texcoord, next_frame));

  vec4 norm_sample = mix(norm_sample0, norm_sample1, frac);

#else // ANIMATEDNORMALMAP == 1
  vec4 norm_sample = texture(normalSampler, vec3(l_texcoord, frame));
#endif

#else
  // Static normal map.
  vec4 norm_sample = texture(normalSampler, l_texcoord);
#endif

  float oo_w = 1.0 / l_w;

  vec2 unwarped_refract_texcoord = l_reflectxy_refractyx.zw * oo_w;

  vec3 normal = 2 * norm_sample.xyz - 1;

  vec3 origWorldNormal = normalize(l_world_normal);
  vec3 worldTangent = normalize(l_world_tangent);
  vec3 worldBinormal = normalize(l_world_binormal);
  vec3 worldNormal = normalize(worldTangent * normal.y +
                               worldBinormal * normal.x +
                               origWorldNormal * normal.z);
  vec3 worldEyeDir = normalize(l_world_vertex_to_eye);

  vec2 reflect_texcoord;
  vec2 refract_texcoord;

  //float water_volume_dist = 1000.0;

  vec4 N;
  N.xy = normal.xy;
  N.w = normal.x;
  N.z = normal.y;
  vec4 dependent_texcoords = N * norm_sample.a * u_reflectRefractScale * 0.1;// * fog_value;

  dependent_texcoords += l_reflectxy_refractyx * oo_w;
  reflect_texcoord = dependent_texcoords.xy;
  refract_texcoord = dependent_texcoords.zw;

  vec3 reflect_color = texture(reflectionSampler, reflect_texcoord).rgb;
  reflect_color *= pow(u_reflectTint, vec3(2.2));
  vec3 refract_color = texture(refractionSampler, refract_texcoord).rgb;
  refract_color *= pow(u_refractTint, vec3(2.2));
#if FOG
  // Distance from camera to water surface:
  float water_surf_depth = gl_FragCoord.z;
  float water_surf_dist = calc_dist(water_surf_depth, u_fogNear, u_fogFar);
  //float water_surf_dist = length(l_eye_pos);

  // Distance from camera to floor under water.
  float water_floor_depth = texture(refractionDepthSampler, refract_texcoord).x;
  float water_floor_dist = calc_dist(water_floor_depth, u_fogNear, u_fogFar);

  float water_volume_dist = water_floor_dist - water_surf_dist;

  float water_fog_factor = calc_fog_factor(water_volume_dist, u_fogStart, u_fogEnd);


  //o_color = vec4(vec3(water_fog_factor), 1.0);
  //return;

  refract_color = mix(refract_color, pow(u_fogColor / vec3(255.0), vec3(2.2)), water_fog_factor);
#endif

  float NdotV = clamp(dot(worldNormal, worldEyeDir), 0, 1);
  float fresnel = pow(1.0 - NdotV, u_fresnelExponent.x);

  // Get lightmap color.
  //vec3 L0 = textureArrayBicubic(lightmapSampler, vec3(l_texcoord_lightmap, 0)).rgb;
  //vec3 L1y = textureArrayBicubic(lightmapSampler, vec3(l_texcoord_lightmap, 1)).rgb;
  //vec3 L1z = textureArrayBicubic(lightmapSampler, vec3(l_texcoord_lightmap, 2)).rgb;
  //vec3 L1x = textureArrayBicubic(lightmapSampler, vec3(l_texcoord_lightmap, 3)).rgb;
  //vec3 diffuseLighting;
  //diffuseLighting = L0 + L1x * worldNormal.x + L1y * worldNormal.y + L1z * worldNormal.z;

  //vec3 color = vec3(0.0);//diffuseLighting;
  vec3 color = mix(refract_color, reflect_color, fresnel);

  o_color = vec4(color, 1.0);//fresnel);
}
