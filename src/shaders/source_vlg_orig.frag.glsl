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

in vec2 l_texcoord;
in vec3 l_worldPosition;
in vec3 l_worldNormal;
in vec3 l_worldTangent;
in vec3 l_worldBinormal;
in vec4 l_vertexColor;
in vec3 l_worldVertexToEye;

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

uniform sampler2D normalTexture;

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
//uniform sampler2D envMapMaskTexture;
//uniform vec3 envMapTint;
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

#elif defined(NUM_LIGHTS) && NUM_LIGHTS > 0
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

  return diff;
}

void specularAndRimTerms(inout vec3 specularLighting, inout vec3 rimLighting,
                         vec3 lightDir, vec3 eyeDir, vec3 worldNormal, float specularExponent,
                         vec3 color, float rimExponent, float fresnel) {
  specularExponent *= 4.0;
  rimExponent *= 4.0;

  // Blinn-Phong specular.  Half-angle instead of reflection vector.
  vec3 halfDir = normalize(lightDir + eyeDir);
  float NdotH = clamp(dot(worldNormal, halfDir), 0, 1);
  //vec3 vReflect = 2 * worldNormal * dot(worldNormal, eyeDir) - eyeDir;
  //float NdotH = clamp(dot(vReflect, lightDir), 0, 1);
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

  diffuseLighting += lightColor * lightAtten * diffuseTerm(L, worldNormal);

  #if PHONG
  vec3 localSpecular = vec3(0.0);
  vec3 localRim = vec3(0.0);
  specularAndRimTerms(specularLighting, rimLighting, L, eyeDir, worldNormal, specularExponent,
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

#endif // NUM_LIGHTS

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
#if (SELFILLUM && !SELFILLUMMASK) || BASEMAPALPHAPHONGMASK
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

  float specMask;
  vec4 normalTexel = texture(normalTexture, l_texcoord);
  vec3 tangentSpaceNormal = normalize(2.0 * normalTexel.xyz - 1.0);
#ifndef BASEMAPALPHAPHONGMASK
  // Alpha is not a phong mask.  It's in the normal alpha.
  specMask = normalTexel.a;
#else
  // Base alpha is the phong mask.
  specMask = baseColor.a;
#endif

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
  fFresnelRanges = Fresnel(worldNormal, worldVertToEyeDir, phongFresnelRanges);
  specularTint = mix(vec3(1.0), albedo.rgb, vSpecExpMap.g);
  specularTint = (phongTint.r >= 0) ? phongTint.rgb : specularTint;
#endif

  doLighting(diffuseLighting, specularLighting, rimLighting, worldNormal,
             l_worldPosition, worldVertToEyeDir, fSpecExp, fRimExp, fFresnelRanges, NUM_LIGHTS);

#ifndef PHONGWARP
  specularLighting *= fFresnelRanges;
#endif
  specularLighting *= specMask * phongBoost;

#endif // NUM_LIGHTS

//#if ENVMAP
//
//#if SELFILLUMFRESNEL
//  float envMapMask = mix(baseColor.a, invertPhongMask, envMapSpecMaskControl);
//#else
//  float envMapMask = mix(baseColor.a, specMask, envMapSpecMaskControl)
//#endif

//  float NdotV = abs(dot(worldNormal, worldVertToEyeDir)) + 1e-5;

//  vec3 diffuseIrradiance = ambientLookup(worldNormal);
//  vec3 ambientLightingFresnel = fresnelSchlick(specularity, NdotV);
//  vec3 diffuseContributionFactor = vec3(1.0) - ambientLightingFresnel;
//  vec3 diffuseIBL = diffuseContributionFactor * albedo.rgb * diffuseIrradiance;

//  vec3 lookupHigh = textureLod(envMapTexture, normalize(vReflect), int(roughness * 9.0)).rgb;
//  vec3 lookupLow = ambientLookup(normalize(vReflect));
//  vec3 specIrradiance = mix(lookupHigh, lookupLow, roughness * roughness);
//  vec3 specIBL = specIrradiance * envBRDFApprox(specularity, roughness, NdotV);

//  ambientLighting = (diffuseIBL + specIBL);

  //lighting += textureLod(envMapTexture, vReflect, int(roughness * 9.0)).rgb *
  //            envBRDFApprox(specularity, roughness, );

  //envMapColor = (mix(1, fresnelRanges, envMapFresnel.x) *
  //               mix(envMapMask, 1 - envMapMask, invertPhongMask)) *
  //              texture(envMapTexture, vReflect) *
  //              envMapTint;

//#endif // ENVMAP

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
  float rimMultiply = fRimMask * fRimFresnel;
  rimLighting *= rimMultiply;
  specularLighting = max(specularLighting, rimLighting);
  specularLighting += (rimAmbientColor * rimLightBoost) * clamp(rimMultiply * worldNormal.z, 0, 1);
#endif

  vec3 result = specularLighting * specularTint + diffuseComponent;

  fragColor = vec4(result, alpha);
}
