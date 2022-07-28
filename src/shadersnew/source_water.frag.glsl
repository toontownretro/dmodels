#version 430

#pragma combo BLAH 0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common.inc.glsl"

uniform sampler2DArray lightmapSampler;
uniform sampler2D reflectionSampler;
uniform sampler2D refractionSampler;

in vec2 l_texcoord;
in vec2 l_texcoord_lightmap;
in vec4 l_texcoord_reflection;
in vec3 l_world_normal;
in vec3 l_world_eye_to_vert;
in vec3 l_world_tangent;
in vec3 l_world_binormal;

out vec4 o_color;

void
main() {

  vec2 refl_coords = l_texcoord_reflection.xy / l_texcoord_reflection.w;
  vec3 reflect_color = texture(reflectionSampler, refl_coords).rgb;
  vec3 refract_color = texture(refractionSampler, refl_coords).rgb;

  vec3 worldNormal = normalize(l_world_normal);
  vec3 vertToEyeDir = normalize(l_world_eye_to_vert);
  float fresnel = clamp(1 - dot(worldNormal, vertToEyeDir), 0, 1);
  fresnel *= fresnel;

  // Get lightmap color.
  vec3 L0 = textureArrayBicubic(lightmapSampler, vec3(l_texcoord_lightmap, 0)).rgb;
  vec3 L1y = textureArrayBicubic(lightmapSampler, vec3(l_texcoord_lightmap, 1)).rgb;
  vec3 L1z = textureArrayBicubic(lightmapSampler, vec3(l_texcoord_lightmap, 2)).rgb;
  vec3 L1x = textureArrayBicubic(lightmapSampler, vec3(l_texcoord_lightmap, 3)).rgb;
  vec3 diffuseLighting;
  diffuseLighting = L0 + L1x * worldNormal.x + L1y * worldNormal.y + L1z * worldNormal.z;

  vec3 color = diffuseLighting;
  color += mix(reflect_color, refract_color, fresnel);

  o_color = vec4(color, 1.0);
}
