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
#pragma combo HAS_SHADOW_SUNLIGHT 0 1
#pragma combo CLIPPING        0 1
#pragma combo DETAIL          0 1

// All of these are dependent on direct lighting.
#pragma skip $[and $[not $[DIRECT_LIGHT]],$[or $[PHONGWARP],$[LIGHTWARP],$[HAS_SHADOW_SUNLIGHT]]]
// These are dependent on phong.
#pragma skip $[and $[not $[PHONG]],$[or $[PHONGWARP],$[RIMLIGHT]]]
// These are dependent on selfillum.
#pragma skip $[and $[not $[SELFILLUM]],$[SELFILLUMMASK]]
// Bumpmap is useless without these.
#pragma skip $[and $[BUMPMAP],$[not $[or $[RIMLIGHT],$[eq $[AMBIENT_LIGHT],2],$[DIRECT_LIGHT],$[ENVMAP]]]]

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_frag.inc.glsl"
#include "shadersnew/common_shadows_frag.inc.glsl"

// Pixel shader inputs.
in vec4 l_world_pos;
in vec3 l_world_normal;
in vec3 l_world_tangent;
in vec3 l_world_binormal;
in vec3 l_world_vertex_to_eye;
in vec4 l_vertex_color;
in vec4 l_eye_pos;
in vec2 l_texcoord;
in vec3 l_vertex_light;

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

#if HAS_SHADOW_SUNLIGHT
uniform sampler2DArrayShadow p3d_CascadeShadowMap;
in vec4 l_cascadeCoords[4];
layout(constant_id = 6) const int NUM_CASCADES = 0;
#endif // HAS_SHADOW_SUNLIGHT

// Uniforms for volume tiled lighting.
uniform samplerBuffer p3d_StaticLightBuffer;
uniform samplerBuffer p3d_DynamicLightBuffer;
uniform isamplerBuffer p3d_LightListBuffer;
uniform vec2 p3d_LensNearFar;
uniform vec2 p3d_WindowSize;
uniform vec3 p3d_LightLensDiv;
uniform vec2 p3d_LightLensZScaleBias;
#include "shadersnew/common_clustered_lighting.inc.glsl"

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
layout(constant_id = 13) const int BLEND_MODE = 0;
uniform struct p3d_FogParameters {
  vec4 color;
  float density;
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

// Clip planes.
#if CLIPPING
uniform vec4 p3d_WorldClipPlane[4];
layout(constant_id = 10) const int NUM_CLIP_PLANES = 0;
#endif

layout(constant_id = 11) const bool BAKED_VERTEX_LIGHT = false;

#if DETAIL
uniform sampler2D detailSampler;
uniform vec2 detailParams;
uniform vec3 detailTint;
#define detailScale (detailParams.y)
#define detailBlendFactor (detailParams.x)
layout(constant_id = 14) const int DETAIL_BLEND_MODE = 0;
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
  float f = 1 - clamp(dot(normal, eyeDir), 0, 1);
  f *= f;
  float result = f;
  if (f > 0.5) {
    result = mix(ranges.y, ranges.z, (2 * f) - 1);
  } else {
    result = mix(ranges.x, ranges.y, 2 * f);
  }
  return result;
}

vec3
ambientLookup(vec3 wnormal) {
#if AMBIENT_LIGHT == 2
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

#if DIRECT_LIGHT
vec3 diffuseTerm(float NdotL, float shadow) {
  float result;
  if (false) {//(HALFLAMBERT) {
    result = clamp(NdotL * 0.5 + 0.5, 0, 1);
#if !LIGHTWARP
    result *= result;
#endif
  } else {
    result = clamp(NdotL, 0, 1);
  }

  //result *= shadow;

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
void doLight(in ClusterLightData light, inout vec3 diffuseLighting, inout vec3 specularLighting, inout vec3 rimLighting,
             vec3 worldNormal, vec3 worldPos, vec3 eyeDir, float specularExponent, float rimExponent,
             float fresnel) {

  vec3 lightColor = light.color;
  vec3 lightPos = light.pos;
  vec3 lightDir = normalize(light.direction);
  vec3 attenParams = vec3(light.constant_atten, light.linear_atten, light.quadratic_atten);
  vec4 spotParams = vec4(light.spot_exponent, light.spot_stopdot, light.spot_stopdot2, light.spot_oodot);
  float lightDist = 0.0;
  float lightAtten = 1.0;

  float shadowFactor = 1.0;

  float fNdotL;

  vec3 L;
  if (light.type == LIGHT_TYPE_DIRECTIONAL) {
    L = lightDir;

    fNdotL = max(0.0, dot(L, worldNormal));

#if HAS_SHADOW_SUNLIGHT
#if !LIGHTWARP
    if (fNdotL > 0.0) {
      GetSunShadow(shadowFactor, p3d_CascadeShadowMap, l_cascadeCoords, fNdotL, NUM_CASCADES);
    }
#else
    GetSunShadow(shadowFactor, p3d_CascadeShadowMap, l_cascadeCoords, fNdotL, NUM_CASCADES);
#endif
#endif

  } else {
    L = lightPos - worldPos;
    lightDist = max(0.00001, length(L));
    L = normalize(L);

    fNdotL = max(0.0, dot(L, worldNormal));

    //if (fNdotL > 0.0) {
      lightAtten = 1.0 / (attenParams.x + attenParams.y * lightDist + attenParams.z * (lightDist * lightDist));
      lightAtten *= (light.atten_radius > 0.0) ? (1.0 - (lightDist / light.atten_radius)) : 1.0;
      lightAtten = max(0.0, lightAtten);

      if (light.type == LIGHT_TYPE_SPOT) {
        // Spotlight cone attenuation.
        float cosTheta = clamp(dot(L, -lightDir), 0, 1);
        float spotAtten = (cosTheta - spotParams.z) * spotParams.w;
        spotAtten = max(0.0001, spotAtten);
        spotAtten = pow(spotAtten, spotParams.x);
        spotAtten = clamp(spotAtten, 0, 1);
        lightAtten *= spotAtten;
      }
    //}
  }

  lightAtten *= shadowFactor;

  vec3 NdotL = diffuseTerm(fNdotL, shadowFactor);

  diffuseLighting += lightColor * lightAtten * NdotL;

#if PHONG
  vec3 localSpecular = vec3(0.0);
  vec3 localRim = vec3(0.0);
  //lightAtten *= shadowFactor;
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
    doLight(light, diffuseLighting, specularLighting, rimLighting, worldNormal, worldPos,
            eyeDir, specularExponent, rimExponent, fresnel);
  }

  OPEN_ITERATE_CLUSTERED_LIGHTS()
    fetch_cluster_light(light_index, p3d_StaticLightBuffer, p3d_DynamicLightBuffer, light);
    doLight(light, diffuseLighting, specularLighting, rimLighting, worldNormal, worldPos,
            eyeDir, specularExponent, rimExponent, fresnel);
  CLOSE_ITERATE_CLUSTERED_LIGHTS()
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
#if CLIPPING
  int clip_plane_count = min(4, NUM_CLIP_PLANES);
  for (int i = 0; i < clip_plane_count; ++i) {
    if (dot(p3d_WorldClipPlane[i], l_world_pos) < 0.0) {
      discard;
    }
  }
#endif

  // Determine whether the basetexture alpha is actually alpha,
  // or used as a mask for something else.
  bool baseAlphaIsAlpha = !(hasBaseAlphaSelfIllumMask() || hasBaseMapAlphaEnvMapMask() || hasBaseMapAlphaPhongMask());

  vec4 baseColor = texture(albedoTexture, l_texcoord);

#if DETAIL
  vec4 detailTexel = texture(detailSampler, l_texcoord * detailScale);
  detailTexel *= vec4(detailTint, 1.0);
  baseColor = texture_combine(baseColor, detailTexel, DETAIL_BLEND_MODE, detailBlendFactor);
#endif

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
  //o_color = vec4(diffuseLighting, alpha);
  //return;
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
#if !PHONGWARP
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
  o_color.rgb = do_fog(o_color.rgb, l_eye_pos.xyz, fog_color, p3d_Fog.density,
                       p3d_Fog.end, p3d_Fog.scale, FOG_MODE);
#endif
}
