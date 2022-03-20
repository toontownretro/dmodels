#version 330

#pragma combo BUMPMAP     0 1
#pragma combo ENVMAP      0 1
#pragma combo ENVMAPMASK  0 1
#pragma combo SELFILLUM   0 1
#pragma combo SUNLIGHT    0 1
#pragma combo FOG         0 1
#pragma combo ALPHA_TEST  0 1

#pragma skip $[and $[not $[ENVMAP]],$[ENVMAPMASK]]

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_frag.inc.glsl"
#include "shadersnew/common.inc.glsl"
#include "shadersnew/common_shadows_frag.inc.glsl"

uniform sampler2D baseTexture;

#if BUMPMAP
uniform sampler2D normalTexture;
layout(constant_id = 0) const bool SSBUMP = false;
#endif // BUMPMAP

#if ENVMAP
uniform samplerCube envmapTexture;
#if ENVMAPMASK
uniform sampler2D envmapMaskTexture;
#endif
uniform vec3 envmapTint;
uniform vec3 envmapContrast;
uniform vec3 envmapSaturation;
layout(constant_id = 1) const bool BASEALPHAENVMAPMASK = false;
layout(constant_id = 2) const bool NORMALMAPALPHAENVMAPMASK = false;
#endif // ENVMAP

#if SUNLIGHT
uniform struct p3d_LightSourceParameters {
  vec4 color;
  vec4 direction;
} p3d_LightSource[1];
uniform sampler2DArrayShadow p3d_CascadeShadowMap;
in vec4 l_cascadeCoords[4];
layout(constant_id = 3) const int NUM_CASCADES = 0;
#endif // SUNLIGHT

#if FOG
uniform struct p3d_FogParameters {
  vec4 color;
  float density;
  float end;
  float scale;
} p3d_Fog;
layout(constant_id = 4) const int FOG_MODE = FM_linear;
#endif // FOG

#if ALPHA_TEST
layout(constant_id = 5) const int ALPHA_TEST_MODE = M_none;
layout(constant_id = 6) const float ALPHA_TEST_REF = 0.0;
#endif // ALPHA_TEST

#if SELFILLUM
uniform vec3 selfIllumTint;
#endif // SELFILLUM

uniform sampler2D lightmapTexture;

in vec2 l_texcoord;
in vec2 l_texcoordLightmap;
in vec4 l_eyePos;
in vec4 l_vertexColor;
in vec4 l_worldPos;
in vec3 l_worldNormal;
in vec3 l_worldTangent;
in vec3 l_worldBinormal;
in vec3 l_worldVertexToEye;

out vec4 o_color;

#define OO_SQRT_2 0.70710676908493042
#define OO_SQRT_3 0.57735025882720947
#define OO_SQRT_6 0.40824821591377258
// sqrt( 2 / 3 )
#define OO_SQRT_2_OVER_3 0.81649661064147949
const vec3 g_localBumpBasis[3] = vec3[](
    vec3(OO_SQRT_2_OVER_3, 0.0f, OO_SQRT_3),
    vec3(-OO_SQRT_6, OO_SQRT_2, OO_SQRT_3),
    vec3(-OO_SQRT_6, -OO_SQRT_2, OO_SQRT_3)
);

bool hasSelfIllum() {
#if SELFILLUM
  return true;
#else
  return false;
#endif
}

bool baseAlphaIsEnvMapMask() {
#if !ENVMAP
  return false;
#else
  return BASEALPHAENVMAPMASK;
#endif
}

bool normalAlphaIsEnvMapMask() {
#if !ENVMAP
  return false;
#else
  return NORMALMAPALPHAENVMAPMASK;
#endif
}

bool hasSSBump() {
#if !BUMPMAP
  return false;
#else
  return SSBUMP;
#endif
}

void
main() {
  float alpha = l_vertexColor.a;
  vec4 baseSample = texture(baseTexture, l_texcoord);
  if (!baseAlphaIsEnvMapMask() && !hasSelfIllum()) {
    alpha *= baseSample.a;
  }

#if ALPHA_TEST
  if (!do_alpha_test(alpha, ALPHA_TEST_MODE, ALPHA_TEST_REF)) {
    discard;
  }
#endif

  vec3 albedo = baseSample.rgb * l_vertexColor.rgb;

  // Vertex world normal without normal map applied.
  vec3 origWorldNormal = normalize(l_worldNormal);
  vec3 worldTangent = normalize(l_worldTangent);
  vec3 worldBinormal = normalize(l_worldBinormal);
  vec3 worldVertToEyeDir = normalize(l_worldVertexToEye);

#if BUMPMAP
  vec4 normalTexel = texture(normalTexture, l_texcoord);
#else
  vec4 normalTexel = vec4(0.5, 0.5, 1.0, 1.0);
#endif

  vec3 tangentSpaceNormal;
  if (!hasSSBump()) {
    tangentSpaceNormal = normalize(2.0 * normalTexel.xyz - 1.0);
  } else {
    tangentSpaceNormal = normalize(g_localBumpBasis[0] * normalTexel.x +
                                   g_localBumpBasis[1] * normalTexel.y +
                                   g_localBumpBasis[2] * normalTexel.z);
  }
  vec3 worldNormal = normalize(worldTangent * tangentSpaceNormal.x + worldBinormal * tangentSpaceNormal.y + origWorldNormal * tangentSpaceNormal.z);

  vec3 diffuseLighting = textureBicubic(lightmapTexture, l_texcoordLightmap).rgb;

#if SUNLIGHT
  float NdotL;
  if (hasSSBump()) {
    // Crazy SSBump NdotL method.
    vec3 toLight = normalize(p3d_LightSource[0].direction.xyz);
    vec3 tangentToLight;
    tangentToLight.x = dot(toLight, worldTangent);
    tangentToLight.y = dot(toLight, worldBinormal);
    tangentToLight.z = dot(toLight, origWorldNormal);
    tangentToLight = normalize(tangentToLight);
    NdotL = clamp(normalTexel.x * dot(tangentToLight, g_localBumpBasis[0]) +
                  normalTexel.y * dot(tangentToLight, g_localBumpBasis[1]) +
                  normalTexel.z * dot(tangentToLight, g_localBumpBasis[2]), 0.0, 1.0);
  } else {
    NdotL = clamp(dot(normalize(p3d_LightSource[0].direction.xyz), worldNormal), 0.0, 1.0);
  }

  if (NdotL > 0.0) {
    float sunShadowFactor = 0.0;
    GetSunShadow(sunShadowFactor, p3d_CascadeShadowMap, l_cascadeCoords, NdotL, NUM_CASCADES);
    vec3 light = p3d_LightSource[0].color.rgb * sunShadowFactor * NdotL;
    diffuseLighting += light;
  }
#endif // SUNLIGHT

#if SELFILLUM
  diffuseLighting += selfIllumTint * albedo * baseSample.a;
#endif

  vec3 specularLighting = vec3(0.0);

#if ENVMAP
  float specMask = 1.0;
  if (baseAlphaIsEnvMapMask()) {
    specMask *= 1.0 - baseSample.a;
  } else if (normalAlphaIsEnvMapMask()) {
    specMask *= normalTexel.a;
  }
#if ENVMAPMASK
  specMask *= texture(envmapMaskTexture, l_texcoord).x;
#endif

  vec3 reflectVec = 2 * worldNormal * dot(worldNormal, worldVertToEyeDir) - worldVertToEyeDir;

  specularLighting += texture(envmapTexture, reflectVec).rgb * specMask * envmapTint;

#endif // ENVMAP

  vec3 diffuseComponent = albedo * diffuseLighting;

  vec3 result = diffuseComponent + specularLighting;

  o_color = vec4(result, alpha);

#if FOG
  o_color.rgb = do_fog(o_color.rgb, l_eyePos.xyz, p3d_Fog.color.rgb,
                       p3d_Fog.density, p3d_Fog.end, p3d_Fog.scale,
                       FOG_MODE);
#endif
}
