#version 430

// This shader implements the Source Engine Phong-based lighting model
// for compatibility with TF2's materials.  I originally experimented with
// converting TF2 materials into PBR parameters with the StandardMaterial,
// but there really is no direct conversion into PBR metal-roughness.  The
// TF2 materials were authored for the Source Engine lighting model, and
// will have to be completely reauthored if they were to be migrated to
// PBR.  Maybe in the future...

#extension GL_GOOGLE_include_directive : enable
#include "shaders/common_fog_frag.inc.glsl"
#include "shaders/common_frag.inc.glsl"
#include "shaders/common_shadows_frag.inc.glsl"

in vec2 l_texcoord;
in vec3 l_worldPosition;
in vec3 l_worldNormal;
in vec3 l_worldTangent;
in vec3 l_worldBinormal;
in vec4 l_vertexColor;
in vec3 l_worldVertexToEye;

//#if FOG
in vec3 l_eyePosition;
//#endif

const float PI = 3.14159265359;

//#ifdef RIMLIGHT
//#undef RIMLIGHT
//#endif

//#ifdef LIGHTWARP
//#undef LIGHTWARP
//#endif

#ifdef HALFLAMBERT
#undef HALFLAMBERT
#endif

// If we have clip planes.
#if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
uniform vec4 p3d_WorldClipPlane[NUM_CLIP_PLANES];
#endif

uniform sampler2D albedoTexture;

#if BUMPMAP
uniform sampler2D normalTexture;
#endif

#if LIGHTWARP
uniform sampler1D lightWarpTexture;
#endif

#if PHONG
//#define HALFLAMBERT 1
// Phong exponent, phong albedo tint, phong boost, exponent factor
uniform vec3 phongParams;
#define phongExponent (phongParams.x)
#define phongAlbedoTint bool(int(phongParams.y))
#define phongBoost (phongParams.z)
uniform vec3 phongFresnelRanges;
uniform vec3 phongTint;
uniform vec2 remapParams;
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

#endif // PHONG

#if SELFILLUM
uniform vec3 selfIllumTint;
//uniform vec4 selfIllumFresnelMinMaxExp;
#if SELFILLUMMASK
uniform sampler2D selfIllumMaskTexture;
#endif
#endif

#if ENVMAP
uniform samplerCube envMapTexture;
uniform sampler2D brdfLut;
//uniform sampler2D envMapMaskTexture;
uniform vec3 envMapTint;
//uniform vec2 envMapContrastSaturation;
#endif

#if NUM_LIGHTS > 0

uniform struct p3d_LightSourceParameters {
  vec4 color;
  vec4 position;
  vec4 direction;
  vec4 spotParams;
  vec3 attenuation;
} p3d_LightSource[NUM_LIGHTS];

#ifdef HAS_SHADOW_SUNLIGHT
  uniform sampler2DArrayShadow p3d_CascadeShadowMap;
  uniform mat4 p3d_CascadeMVPs[PSSM_SPLITS];
  in vec4 l_pssmCoords[PSSM_SPLITS];
  uniform vec4 wspos_view;
#endif

// We may have an L2 spherical harmonics ambient
// probe...
#if AMBIENT_PROBE
uniform vec3 ambientProbe[9];

// ..or a uniform ambient color.
#elif AMBIENT_LIGHT
uniform struct {
  vec4 ambient;
} p3d_LightModel;
#endif

#endif // LIGHTING

out vec4 fragColor;

vec3 fresnelSchlick(vec3 F0, float cosTheta) {
  return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float microfacetDistribution(float cosLh, float roughness) {
  float alpha = roughness * roughness;
  float alphaSq = alpha * alpha;
  float denom = (cosLh * cosLh) * (alphaSq - 1.0) + 1.0;
  return alphaSq / (PI * denom * denom);
}

float gaSchlickG1(float cosTheta, float k) {
  return cosTheta / (cosTheta * (1.0 - k) + k);
}

float visibilityOcclusion(float cosLi, float cosLo, float roughness) {
  float r = roughness + 1.0;
  float k = (r * r) / 8.0;
  return gaSchlickG1(cosLi, k) * gaSchlickG1(cosLo, k);
}

// Monte Carlo integration, approximate analytic version based on Dimitar Lazarov's work
// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
vec3 envBRDFApprox(vec3 SpecularColor, float Roughness, float NoV) {
  const vec4 c0 = vec4(-1, -0.0275, -0.572, 0.022);
  const vec4 c1 = vec4(1, 0.0425, 1.04, -0.04);
  vec4 r = Roughness * c0 + c1;
  float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
  vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
  return SpecularColor * AB.x + AB.y;
}

float diffuseFunction() {
  return 1.0 / PI;
}

vec3 ambientLookup(vec3 wnormal) {
#if AMBIENT_PROBE
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

#elif AMBIENT_LIGHT
  return p3d_LightModel.ambient.rgb;

#elif NUM_LIGHTS > 0
  return vec3(0.0);

#else
  return vec3(1.0);

#endif
}

#if NUM_LIGHTS > 0

vec3 diffuseTerm(vec3 L, vec3 normal) {
  float result;
  float NdotL = dot(normal, L);
  #ifdef HALFLAMBERT
    result = clamp(NdotL * 0.5 + 0.5, 0, 1);
    #ifndef LIGHTWARP
      result *= result;
    #endif
  #else
    result = clamp(NdotL, 0, 1);
  #endif

  vec3 diff = vec3(result);
  #ifdef LIGHTWARP
    diff = 2.0 * texture(lightWarpTexture, result).rgb;
  #endif

  // Normalize it for energy conservation.
  // http://blog.stevemcauley.com/2011/12/03/energy-conserving-wrapped-diffuse/
  #ifdef HALFLAMBERT
    diff *= 0.5;
  #endif

  return diff;
}

// Accumulates lighting for the given light index.
void doLight(int i, inout vec3 lighting,
             vec3 worldNormal, vec3 worldPos, vec3 eyeDir, vec3 specularity, float roughness, float rimRoughness,
             vec3 albedo) {

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

    #ifdef HAS_SHADOW_SUNLIGHT
      float lshad = 0.0;
      GetSunShadow(lshad, p3d_CascadeShadowMap, l_pssmCoords, max(0.0, dot(worldNormal, L)), wspos_view.xyz, worldPos);
      lightAtten *= lshad;
    #endif

  } else {
    L = lightPos - worldPos;
    lightDist = length(L);
    L = L / lightDist;

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

  float cosLightOut = clamp(abs(dot(worldNormal, eyeDir)), 0, 1);
  vec3 halfAngle = normalize(L + eyeDir);
  float cosHalfAngle = max(0.0, dot(worldNormal, halfAngle));
  float cosLightIn = max(0.0, dot(worldNormal, L));

  vec3 F = fresnelSchlick(specularity, max(0.0, dot(halfAngle, eyeDir)));
  float D = microfacetDistribution(cosHalfAngle, roughness);
  float V = visibilityOcclusion(cosLightIn, cosLightOut, roughness);

  vec3 kd = vec3(1.0) - F;

  vec3 localDiffuse = kd * albedo * diffuseTerm(L, worldNormal);
  vec3 localSpecular = (F * D * V) / max(0.00001, 4.0 * cosLightIn * cosLightOut);
  localSpecular *= cosLightIn;
  lighting += (localDiffuse + localSpecular) * lightColor * lightAtten;
}

void doLighting(inout vec3 lighting,
                vec3 worldNormal, vec3 worldPos, vec3 eyeDir, vec3 specularity, float roughness, float rimRoughness,
                vec3 albedo, int numLights) {
  // Start diffuse at ambient color.
  //diffuseLighting = ambientLookup(worldNormal);
  for (int i = 0; i < numLights; i++) {
    doLight(i, lighting, worldNormal, worldPos,
            eyeDir, specularity, roughness, rimRoughness, albedo);
  }
}

#endif // NUM_LIGHTS

float remapValClamped(float val, float A, float B, float C, float D) {
  float cVal = (val - A) / (B - A);
  cVal = clamp(cVal, 0.0, 1.0);
  return C + (D - C) * cVal;
}

float Fresnel4(vec3 vNormal, vec3 vEyeDir) {
  float fresnel = clamp(1 - dot(vNormal, vEyeDir), 0, 1);
  fresnel = fresnel * fresnel;
  return fresnel * fresnel;
}

void main() {
  // Clipping first!
#if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
  for (int i = 0; i < NUM_CLIP_PLANES; i++) {
    if (!ClipPlaneTest(l_worldPosition, p3d_WorldClipPlane[i])) {
      // pixel outside of clip plane interiors
      discard;
    }
  }
#endif

  vec4 baseColor = texture(albedoTexture, l_texcoord);
  float alpha;
#if (SELFILLUM && !SELFILLUMMASK) || BASEMAPALPHAPHONGMASK || (ENVMAP && MAT_ENVMAP && !NORMALMAPALPHAENVMAPMASK)
  // Base alpha used for something else, don't interpret it as alpha.
  alpha = l_vertexColor.a;
#else
  // Base alpha is actually an alpha value.
  alpha = baseColor.a * l_vertexColor.a;
#endif

#ifdef ALPHA_TEST
  if (!AlphaTest(alpha)) {
    discard;
  }
#endif

  vec3 albedo = baseColor.rgb * l_vertexColor.rgb;

  // Re-normalize interpolated vectors.
  vec3 worldNormal = normalize(l_worldNormal);
  vec3 worldTangent = normalize(l_worldTangent);
  vec3 worldBinormal = normalize(l_worldBinormal);
  vec3 worldVertToEyeDir = normalize(l_worldVertexToEye);

  vec3 lighting = vec3(0.0);
  vec3 specularity = vec3(0.04);
  vec3 rimSpecularity = vec3(0.0);
  float roughness = 1.0;
  float rimRoughness = 1.0;

  float fSpecExp = 1;
#if RIMLIGHT
  float fRimExp = rimLightExponent;
#else
  float fRimExp = 1;
#endif
  float fRimMask = 1;

  float specMask;

#if BUMPMAP
  vec4 normalTexel = texture(normalTexture, l_texcoord);
  vec3 tangentSpaceNormal = normalize(2.0 * normalTexel.xyz - 1.0);

#if PHONG

#if !BASEMAPALPHAPHONGMASK
  specMask = normalTexel.a;
#endif

#elif ENVMAP

#if NORMALMAPALPHAENVMAPMASK
  specMask = normalTexel.a;
#endif

#endif

  // Get a new world-space normal from the normal map normal.
  worldNormal = normalize(worldTangent * tangentSpaceNormal.x + worldBinormal * tangentSpaceNormal.y + worldNormal * tangentSpaceNormal.z);
#endif // BUMPMAP

#if PHONG

#if BASEMAPALPHAPHONGMASK
  specMask = baseColor.a;
#endif

#elif ENVMAP

#if !NORMALMAPALPHAENVMAPMASK
  specMask = 1.0 - baseColor.a;
#endif

#endif

  vec3 vReflect = 2 * worldNormal * dot(worldNormal, worldVertToEyeDir) - worldVertToEyeDir;

  vec3 rimAmbientColor = ambientLookup(worldVertToEyeDir);

#if defined(NUM_LIGHTS) && NUM_LIGHTS > 0
  // We have some local lights.

#if PHONG
  vec4 vSpecExpMap = texture(phongExponentTexture, l_texcoord);
#if RIMLIGHT
  fRimMask = mix(1.0, vSpecExpMap.a, rimMaskControl);
#endif
#if PHONGEXPONENTFACTOR
  fSpecExp = (1.0 + phongExponent * vSpecExpMap.r);
#else
  fSpecExp = (phongExponent >= 0.0) ? phongExponent : (1.0 + 149.0 * vSpecExpMap.r);
#endif
  //specularity = mix(vec3(0.04), albedo.rgb, vSpecExpMap.g);
  //specularity *= phongTint.rgb;
  //specularity = (phongTint.r >= 0) ? phongTint.rgb : specularity;
  specularity = vec3(0.04);
  specularity *= phongTint.rgb;
  roughness = 1 - pow((fSpecExp * phongBoost / remapParams.x) * clamp(specMask, 0, 1), remapParams.y);
  //roughness = pow(remapParams.x / ((fSpecExp * phongBoost) * specMask + remapParams.x), remapParams.y);
  //fragColor = vec4(roughness, roughness, roughness, 1.0);
  //return;
#endif

  doLighting(lighting, worldNormal,
             l_worldPosition, worldVertToEyeDir, specularity, roughness, rimRoughness, albedo.rgb, NUM_LIGHTS);

#endif // NUM_LIGHTS

  vec3 ambientLighting = vec3(0.0);

#if ENVMAP
//
//#if SELFILLUMFRESNEL
//  float envMapMask = mix(baseColor.a, invertPhongMask, envMapSpecMaskControl);
//#else
//  float envMapMask = mix(baseColor.a, specMask, envMapSpecMaskControl)
//#endif

#if !PHONG && MAT_ENVMAP
  roughness = 1 - pow(specMask * clamp(max(envMapTint.r, max(envMapTint.g, envMapTint.b)), 0, 1), 0.115);
#else
  roughness = 1.0;
#endif

  float NdotV = clamp(abs(dot(worldNormal, worldVertToEyeDir)), 0, 1);

  vec3 diffuseIrradiance = ambientLookup(worldNormal);
  vec3 ambientLightingFresnel = fresnelSchlick(specularity, NdotV);
  vec3 diffuseContributionFactor = vec3(1.0) - ambientLightingFresnel;
  vec3 diffuseIBL = diffuseContributionFactor * albedo.rgb * diffuseIrradiance;

  // NOTE: Assumes a 512x512 cubemap.
  vec3 specIrradiance = textureLod(envMapTexture, vReflect, roughness * 9.0).rgb;
  vec3 specIBL = specIrradiance * envBRDFApprox(specularity, roughness, NdotV);

  ambientLighting = (diffuseIBL + specIBL);

  //lighting += textureLod(envMapTexture, vReflect, int(roughness * 9.0)).rgb *
  //            envBRDFApprox(specularity, roughness, );

  //envMapColor = (mix(1, fresnelRanges, envMapFresnel.x) *
  //               mix(envMapMask, 1 - envMapMask, invertPhongMask)) *
  //              texture(envMapTexture, vReflect) *
  //              envMapTint;

#endif // ENVMAP

  //vec3 diffuseComponent = albedo.rgb * diffuseLighting;

#if SELFILLUM
#if SELFILLUMMASK
  vec3 selfIllumMask = texture(selfIllumMaskTexture, l_texcoord).rgb;
#else
  vec3 selfIllumMask = baseColor.aaa;
#endif
  lighting += selfIllumTint * albedo.rgb * selfIllumMask;
#endif

#if RIMLIGHT
  float rimMultiply = fRimMask * Fresnel4(worldNormal, worldVertToEyeDir) * 0.3;
  //rimLighting *= rimMultiply;
//  specularLighting = max(specularLighting, rimLighting);
  lighting += (rimAmbientColor * rimLightBoost) * clamp(rimMultiply * worldNormal.z, 0, 1);
#endif

  vec3 result = ambientLighting + lighting;

  fragColor = vec4(result, alpha);

#ifdef FOG
  ApplyFog(fragColor, vec4(l_eyePosition, 1.0));
#endif
}
