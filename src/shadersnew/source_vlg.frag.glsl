#version 430

#pragma combo DIRECT_LIGHT    0 1
// 0 is no ambient, 1 is flat ambient, 2 is ambient probe
#pragma combo AMBIENT_LIGHT   0 2
#pragma combo PHONG           0 1
#pragma combo PHONGWARP       0 1
#pragma combo LIGHTWARP       0 1
#pragma combo RIMLIGHT        0 1
#pragma combo SELFILLUM       0 1
#pragma combo SELFILLUMMASK   0 1
#pragma combo BUMPMAP         0 1
#pragma combo ENVMAP          0 1
#pragma combo FOG             0 1
#pragma combo ALPHA_TEST      0 1
//#pragma combo HAS_SHADOW_SUNLIGHT 0 1

// All of these are dependent on direct lighting.
#pragma skip $[and $[not $[DIRECT_LIGHT]],$[PHONGWARP],$[LIGHTWARP]]
// These are dependent on phong.
#pragma skip $[and $[not $[PHONG]],$[or $[PHONGWARP],$[RIMLIGHT]]]
// These are dependent on selfillum.
#pragma skip $[and $[not $[SELFILLUM]],$[SELFILLUMMASK]]
// Bumpmap is useless without these.
#pragma skip $[and $[BUMPMAP],$[not $[or $[RIMLIGHT],$[eq $[AMBIENT_LIGHT],2],$[DIRECT_LIGHT],$[ENVMAP]]]]

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_frag.inc.glsl"

// Pixel shader inputs.
in vec4 l_world_pos;
in vec3 l_world_normal;
in vec3 l_world_tangent;
in vec3 l_world_binormal;
in vec3 l_world_vertex_to_eye;
in vec4 l_vertex_color;
in vec4 l_eye_pos;
in vec2 l_texcoord;

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
layout(constant_id = 1) const bool HALFLAMBERT = false;

//#if HAS_SHADOW_SUNLIGHT
//#define MAX_CASCADES 4
//uniform sampler2DArrayShadow p3d_CascadeShadowMap;
//uniform mat4 p3d_CascadeMVPs[MAX_CASCADES];
//in vec4 l_pssmCoords[MAX_CASCADES];
//uniform vec4 wspos_view;
//layout(constant_id = 6) const int NUM_CASCADES = 0;
//#endif

#endif // DIRECT_LIGHT

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
uniform struct p3d_FogParameters {
  vec4 color;
  float density;
  float start;
  float end;
  float scale; // 1.0 / (end - start)
} p3d_Fog;
#endif

#if ENVMAP
uniform samplerCube envMapTexture;
uniform vec3 envMapTint;
layout(constant_id = 2) const bool BASEMAPALPHAENVMAPMASK = false;
layout(constant_id = 3) const bool NORMALMAPALPHAENVMAPMASK = false;
#endif // ENVMAP

#if PHONG
// Phong exponent, phong albedo tint, phong boost, exponent factor
uniform vec3 phongParams;
#define phongExponent (phongParams.x)
#define phongAlbedoTint bool(int(phongParams.y))
#define phongBoost (phongParams.z)
uniform vec3 phongFresnelRanges;
uniform vec3 phongTint;
#if PHONGWARP
uniform sampler2D phongWarpTexture;
#endif
uniform sampler2D phongExponentTexture;

#if RIMLIGHT
// X: exponent, Y: boost, Z: rim mask control
uniform vec3 rimLightParams;
#define rimLightExponent (rimLightParams.x)
#define rimLightBoost (rimLightParams.y)
#define rimMaskControl (rimLightParams.z)
#endif

layout(constant_id = 4) const bool PHONGEXPONENTFACTOR = false;
layout(constant_id = 5) const bool BASEMAPALPHAPHONGMASK = false;
#endif // PHONG

#if SELFILLUM
uniform vec3 selfIllumTint;
#if SELFILLUMMASK
uniform sampler2D selfIllumMaskTexture;
#endif
#endif // SELFILLUM

uniform sampler2D albedoTexture;
#if BUMPMAP
uniform sampler2D normalTexture;
#endif
#if LIGHTWARP
uniform sampler1D lightWarpTexture;
#endif

out vec4 o_color;

float Fresnel(vec3 vNormal, vec3 vEyeDir)
{
    float fresnel = clamp(1 - dot(vNormal, vEyeDir), 0, 1);
    return fresnel * fresnel;
}

float Fresnel4(vec3 vNormal, vec3 vEyeDir)
{
    float fresnel = clamp(1 - dot(vNormal, vEyeDir), 0, 1);
    fresnel = fresnel * fresnel;
    return fresnel * fresnel;
}

float Fresnel(vec3 normal, vec3 eyeDir, float exponent)
{
    float fresnel = clamp(1 - dot(normal, eyeDir), 0, 1);
    return pow(fresnel, exponent);
}

float Fresnel(vec3 normal, vec3 eyeDir, vec3 ranges) {
  float f = clamp(1 - dot(normal, eyeDir), 0, 1);
  f = f * f - 0.5;
  return ranges.y + (f >= 0 ? ranges.z : ranges.x) * f;
}

vec3
ambientLookup(vec3 wnormal) {
#if AMBIENT_LIGHT == 2
  const float c1 = 0.429043;
  const float c2 = 0.511664;
  const float c3 = 0.743125;
  const float c4 = 0.886227;
  const float c5 = 0.247708;
  return (c1 * ambientProbe[8] * (wnormal.x * wnormal.x - wnormal.y * wnormal.y) +
          c3 * ambientProbe[6] * wnormal.z * wnormal.z +
          c4 * ambientProbe[0] -
          c5 * ambientProbe[6] +
          2.0 * c1 * ambientProbe[4] * wnormal.x * wnormal.y +
          2.0 * c1 * ambientProbe[7] * wnormal.x * wnormal.z +
          2.0 * c1 * ambientProbe[5] * wnormal.y * wnormal.z +
          2.0 * c2 * ambientProbe[3] * wnormal.x +
          2.0 * c2 * ambientProbe[1] * wnormal.y +
          2.0 * c2 * ambientProbe[2] * wnormal.z);

#elif AMBIENT_LIGHT == 1
  return p3d_LightModel.ambient.rgb;

#elif DIRECT_LIGHT
  return vec3(0.0);

#else
  return vec3(1.0);
#endif
}

#if DIRECT_LIGHT
vec3 diffuseTerm(vec3 L, vec3 normal, float shadow) {
  float result;
  float NdotL = dot(normal, L);
  if (HALFLAMBERT) {
    result = clamp(NdotL * 0.5 + 0.5, 0, 1);
#if !LIGHTWARP
    result *= result;
#endif
  } else {
    result = clamp(NdotL, 0, 1);
  }

  result *= shadow;

  vec3 diff = vec3(result);
#if LIGHTWARP
  diff = 2.0 * texture(lightWarpTexture, result).rgb;
#endif

  return diff;
}

void specularAndRimTerms(inout vec3 specularLighting, inout vec3 rimLighting,
                         vec3 lightDir, vec3 eyeDir, vec3 worldNormal, float specularExponent,
                         vec3 color, float rimExponent, float fresnel) {

  vec3 vReflect = 2 * worldNormal * dot(worldNormal, eyeDir) - eyeDir;
  float NdotH = clamp(dot(vReflect, lightDir), 0, 1);
  specularLighting = vec3(pow(NdotH, specularExponent));

#if PHONGWARP
  specularLighting *= texture(phongWarpTexture, vec2(specularLighting.x, fresnel)).rgb;
#endif

  float NdotL = max(0.0, dot(worldNormal, lightDir));

  specularLighting *= NdotL;
  specularLighting *= color;

#if RIMLIGHT
  rimLighting = vec3(pow(NdotH, rimExponent));
  rimLighting *= NdotL;
  rimLighting *= color;
#endif
}

// Accumulates lighting for the given light index.
void doLight(int i, inout vec3 diffuseLighting, inout vec3 specularLighting, inout vec3 rimLighting,
             vec3 worldNormal, vec3 worldPos, vec3 eyeDir, float specularExponent, float rimExponent,
             float fresnel) {

  bool isDirectional = p3d_LightSource[i].color.w == 1.0;
  bool isSpot = p3d_LightSource[i].direction.w == 1.0;
  bool isPoint = (!isDirectional && !isSpot);

  vec3 lightColor = p3d_LightSource[i].color.rgb;
  vec3 lightPos = p3d_LightSource[i].position.xyz;
  vec3 lightDir = normalize(p3d_LightSource[i].direction.xyz);
  vec3 attenParams = p3d_LightSource[i].attenuation;
  vec4 spotParams = p3d_LightSource[i].spotParams;
  float lightDist = 0.0;
  float lightAtten = 1.0;

  vec3 L;
  if (isDirectional) {
    L = lightDir;

  } else {
    L = lightPos - worldPos;
    lightDist = max(0.00001, length(L));
    L = normalize(L);

    lightAtten = 1.0 / (attenParams.x + attenParams.y * lightDist + attenParams.z * (lightDist * lightDist));

    if (isSpot) {
      // Spotlight cone attenuation.
      float cosTheta = clamp(dot(L, -lightDir), 0, 1);
      float spotAtten = (cosTheta - spotParams.z) * spotParams.w;
      spotAtten = max(0.0001, spotAtten);
      spotAtten = pow(spotAtten, spotParams.x);
      spotAtten = clamp(spotAtten, 0, 1);
      lightAtten *= spotAtten;
    }
  }

  float shadowFactor = 1.0;
//#if HAS_SHADOW_SUNLIGHT
//  if (isDirectional) {
//    GetSunShadow(shadowFactor, p3d_CascadeShadowMap, l_pssmCoords, vec3(max(0.0, dot(L, worldNormal))),
//                  p3d_CascadeMVPs, wspos_view.xyz, worldPos);
//  }
//#endif

  vec3 NdotL = diffuseTerm(L, worldNormal, shadowFactor);
  //lightAtten *= shadowFactor;

  diffuseLighting += lightColor * lightAtten * NdotL;

#if PHONG
  vec3 localSpecular = vec3(0.0);
  vec3 localRim = vec3(0.0);
  lightAtten *= shadowFactor;
  specularAndRimTerms(localSpecular, localRim, L, eyeDir, worldNormal, specularExponent,
                      lightColor * lightAtten, rimExponent, fresnel);
  specularLighting += localSpecular;
  rimLighting += localRim;
#endif
}

void doLighting(inout vec3 diffuseLighting, inout vec3 specularLighting, inout vec3 rimLighting,
                vec3 worldNormal, vec3 worldPos, vec3 eyeDir, float specularExponent, float rimExponent,
                float fresnel, int numLights) {
  // Start diffuse at ambient color.
  for (int i = 0; i < numLights; i++) {
    doLight(i, diffuseLighting, specularLighting, rimLighting, worldNormal, worldPos,
            eyeDir, specularExponent, rimExponent, fresnel);
  }
}

#endif // DIRECT_LIGHT

bool hasBaseAlphaSelfIllumMask() {
#if SELFILLUM && !SELFILLUMMASK
  return true;
#else
  return false;
#endif
}

bool hasBaseMapAlphaPhongMask() {
#if PHONG
  return BASEMAPALPHAPHONGMASK;
#else
  return false;
#endif
}

bool hasBaseMapAlphaEnvMapMask() {
#if ENVMAP
  return BASEMAPALPHAENVMAPMASK;
#else
  return false;
#endif
}

bool hasNormalMapAlphaEnvMapMask() {
#if ENVMAP
  return NORMALMAPALPHAENVMAPMASK;
#else
  return false;
#endif
}

void
main() {
  // Determine whether the basetexture alpha is actually alpha,
  // or used as a mask for something else.
  bool baseAlphaIsAlpha = !(hasBaseAlphaSelfIllumMask() || hasBaseMapAlphaEnvMapMask() || hasBaseMapAlphaPhongMask());

  vec4 baseColor = texture(albedoTexture, l_texcoord);
  float alpha;
  if (baseAlphaIsAlpha) {
    // Base alpha is actually an alpha value.
    alpha = baseColor.a * l_vertex_color.a;
  } else {
    // Base alpha used for something else, don't interpret it as alpha.
    alpha = l_vertex_color.a;
  }

#if ALPHA_TEST
  if (!do_alpha_test(alpha, ALPHA_TEST_MODE, ALPHA_TEST_REF)) {
    discard;
  }
#endif

  vec3 albedo = baseColor.rgb * l_vertex_color.rgb;

  // Re-normalize interpolated vectors.
  vec3 worldNormal = normalize(l_world_normal);
  vec3 worldTangent = normalize(l_world_tangent);
  vec3 worldBinormal = normalize(l_world_binormal);
  vec3 worldVertToEyeDir = normalize(l_world_vertex_to_eye);

  float specMask;
#if BUMPMAP
  vec4 normalTexel = texture(normalTexture, l_texcoord);
#else
  vec4 normalTexel = vec4(0.5, 0.5, 1.0, 1.0);
#endif
  vec3 tangentSpaceNormal = normalize(2.0 * normalTexel.xyz - 1.0);
  if (!hasBaseMapAlphaPhongMask()) {
    // Alpha is not a phong mask.  It's in the normal alpha.
    specMask = normalTexel.a;
  } else {
    // Base alpha is the phong mask.
    specMask = baseColor.a;
  }

  // Get a new world-space normal from the normal map normal.
  worldNormal = normalize(worldTangent * tangentSpaceNormal.x + worldBinormal * tangentSpaceNormal.y + worldNormal * tangentSpaceNormal.z);

  vec3 vReflect = 2 * worldNormal * dot(worldNormal, worldVertToEyeDir) - worldVertToEyeDir;

  vec3 rimAmbientColor = ambientLookup(worldVertToEyeDir);

  vec3 diffuseLighting = ambientLookup(worldNormal);
  vec3 specularLighting = vec3(0.0);
  vec3 rimLighting = vec3(0.0);
  vec3 specularTint = vec3(0.0);
  float fFresnelRanges = 0.0;
  float fRimFresnel = 0.0;

  float fSpecExp = 1;
#if RIMLIGHT
  float fRimExp = rimLightExponent;
  fRimFresnel = Fresnel4(worldNormal, worldVertToEyeDir);
#else
  float fRimExp = 1;
#endif
  float fRimMask = 1;

#if DIRECT_LIGHT
  // We have some local light sources.

#if PHONG
  vec4 vSpecExpMap = texture(phongExponentTexture, l_texcoord);
#if RIMLIGHT
  fRimMask = mix(1.0, vSpecExpMap.a, rimMaskControl);
#endif
  if (PHONGEXPONENTFACTOR) {
    fSpecExp = (1.0 + phongExponent * vSpecExpMap.r);
  } else {
    fSpecExp = (phongExponent >= 0.0) ? phongExponent : (1.0 + 149.0 * vSpecExpMap.r);
  }
  fFresnelRanges = Fresnel(worldNormal, worldVertToEyeDir, phongFresnelRanges);
  specularTint = mix(vec3(1.0), albedo.rgb, vSpecExpMap.g);
  specularTint = (phongTint.r >= 0) ? phongTint.rgb : specularTint;
#endif // PHONG

  doLighting(diffuseLighting, specularLighting, rimLighting, worldNormal,
             l_world_pos.xyz, worldVertToEyeDir, fSpecExp, fRimExp, fFresnelRanges, NUM_LIGHTS);

#if PHONG
#ifndef PHONGWARP
  specularLighting *= fFresnelRanges;
#endif
  specularLighting *= specMask * phongBoost;
#endif // PHONG

#endif // DIRECT_LIGHT

#if ENVMAP
  float envMapMask = specMask;
  if (BASEMAPALPHAENVMAPMASK) {
    envMapMask = baseColor.a;
  } else if (NORMALMAPALPHAENVMAPMASK) {
    envMapMask = normalTexel.a;
  }

  vec3 envMapColor = textureLod(envMapTexture, vReflect, 0).rgb *
                     envMapTint * envMapMask;
  specularLighting += envMapColor;

#endif // ENVMAP

  vec3 diffuseComponent = albedo.rgb * diffuseLighting;

#if SELFILLUM
#if SELFILLUMMASK
  vec3 selfIllumMask = texture(selfIllumMaskTexture, l_texcoord).rgb;
#else
  vec3 selfIllumMask = baseColor.aaa;
#endif
  diffuseComponent += albedo.rgb * selfIllumTint * selfIllumMask;
#endif

#if RIMLIGHT
  float rimMultiply = fRimMask * fRimFresnel * 0.3;
  rimLighting *= rimMultiply;
  specularLighting = max(specularLighting, rimLighting);
  specularLighting += (rimAmbientColor * rimLightBoost) * clamp(rimMultiply * worldNormal.z, 0, 1);
#endif

  vec3 result = specularLighting * specularTint + diffuseComponent;

  o_color = vec4(result, alpha);

#if FOG
  o_color.rgb = do_fog(o_color.rgb, l_eye_pos.xyz, p3d_Fog.color.rgb, p3d_Fog.density,
                       p3d_Fog.end, p3d_Fog.scale, FOG_MODE);
#endif
}