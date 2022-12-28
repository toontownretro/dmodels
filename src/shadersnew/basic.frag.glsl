#version 330

#pragma combo BASETEXTURE 0 1
#pragma combo ALPHA_TEST 0 1
#pragma combo FOG 0 1
#pragma combo CLIPPING 0 1
#pragma combo PLANAR_REFLECTION 0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_frag.inc.glsl"

// Uniforms for volume tiled lighting.
uniform samplerBuffer p3d_StaticLightBuffer;
uniform samplerBuffer p3d_DynamicLightBuffer;
uniform isamplerBuffer p3d_LightListBuffer;
uniform vec2 p3d_LensNearFar;
uniform vec2 p3d_WindowSize;
uniform vec3 p3d_LightLensDiv;
uniform vec2 p3d_LightLensZScaleBias;
#include "shadersnew/common_clustered_lighting.inc.glsl"

#if BASETEXTURE
in vec2 l_texcoord;
uniform sampler2D base_texture_sampler;
#endif

uniform vec4 p3d_TexAlphaOnly;

in vec4 l_vertex_color;
in vec4 l_eye_position;
in vec4 l_world_position;
in vec3 l_worldNormal;

out vec4 o_color;

// Alpha testing.
#if ALPHA_TEST
layout(constant_id = 0) const int ALPHA_TEST_MODE = M_none;
layout(constant_id = 1) const float ALPHA_TEST_REF = 0.0;
#endif

// Fog handling

#if FOG
layout(constant_id = 2) const int FOG_MODE = FM_linear;
layout(constant_id = 4) const int BLEND_MODE = 0;
uniform struct p3d_FogParameters {
  vec4 color;
  float density;
  float start;
  float end;
  float scale; // 1.0 / (end - start)
} p3d_Fog;
#endif

// Clip planes.
#if CLIPPING
uniform vec4 p3d_WorldClipPlane[4];
layout(constant_id = 3) const int NUM_CLIP_PLANES = 0;
#endif

#if PLANAR_REFLECTION
in vec4 l_texcoordReflection;
uniform sampler2D reflectionSampler;
in vec3 l_worldVertexToEye;
#endif

/**
 *
 */
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

  vec3 albedo = vec3(1, 1, 1);
  float alpha = 1.0;
#if BASETEXTURE
  vec4 base_sample = texture(base_texture_sampler, l_texcoord);
  base_sample += p3d_TexAlphaOnly;
  albedo = base_sample.rgb;
  alpha = base_sample.a;
#endif

  albedo *= l_vertex_color.rgb;
  alpha *= l_vertex_color.a;

#if ALPHA_TEST
  if (!do_alpha_test(alpha, ALPHA_TEST_MODE, ALPHA_TEST_REF)) {
    discard;
  }
#endif

  vec3 diffuse = vec3(1);
  OPEN_ITERATE_CLUSTERED_LIGHTS()
    fetch_cluster_light(light_index, p3d_StaticLightBuffer, p3d_DynamicLightBuffer, light);
    vec3 L = light.pos - l_world_position.xyz;
    float dist = length(L);
    L = normalize(L);

    float NdotL = max(0.0, dot(L, normalize(l_worldNormal)));

    float atten = 1.0 / (light.constant_atten + light.linear_atten * dist + light.quadratic_atten * dist * dist);
    if (light.atten_radius > 0) {
      atten *= 1.0 - (dist / light.atten_radius);
    }
    atten = max(0.0, atten);

    if (light.type == LIGHT_TYPE_SPOT) {
      float cosTheta = clamp(dot(L, -light.direction), 0, 1);
      float spotAtten = (cosTheta - light.spot_stopdot2) * light.spot_oodot;
      spotAtten = max(0.0001, spotAtten);
      spotAtten = pow(spotAtten, light.spot_exponent);
      spotAtten = clamp(spotAtten, 0, 1);
      atten *= spotAtten;
    }

    diffuse += light.color * atten * NdotL;
  CLOSE_ITERATE_CLUSTERED_LIGHTS()

  diffuse *= albedo;

#if PLANAR_REFLECTION
  // Sample planar reflection.
  vec2 reflCoords = l_texcoordReflection.xy / l_texcoordReflection.w;
  vec3 refl = texture(reflectionSampler, reflCoords).rgb;

  // Basic fresnel modulation.
  vec3 wnormal = normalize(l_worldNormal);
  vec3 vertToEyeDir = normalize(l_worldVertexToEye);
  float fresnel = clamp(1 - dot(wnormal, vertToEyeDir), 0, 1);
  fresnel *= fresnel;

  // Add onto final color.
  diffuse += refl * fresnel;
#endif

  o_color = vec4(diffuse, alpha);

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
  o_color.rgb = do_fog(o_color.rgb, l_eye_position.xyz, fog_color, p3d_Fog.density,
                       p3d_Fog.end, p3d_Fog.scale, FOG_MODE);
#endif
}
