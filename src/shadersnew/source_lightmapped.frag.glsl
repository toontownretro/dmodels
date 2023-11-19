#version 330

#pragma combo BUMPMAP     0 1
#pragma combo ENVMAP      0 1
#pragma combo ENVMAPMASK  0 1
#pragma combo SELFILLUM   0 1
#pragma combo SUNLIGHT    0 2
#pragma combo FOG         0 1
#pragma combo ALPHA_TEST  0 1
#pragma combo BASETEXTURE2 0 1
#pragma combo BUMPMAP2     0 1
#pragma combo PLANAR_REFLECTION 0 1
#pragma combo CLIPPING    0 1
#pragma combo DETAIL      0 1
#pragma combo LIGHTMAP    0 1

#pragma skip $[and $[or $[not $[ENVMAP],$[not $[PLANAR_REFLECTION]]]],$[ENVMAPMASK]]
#pragma skip $[and $[PLANAR_REFLECTION],$[ENVMAP]]

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_frag.inc.glsl"
#include "shadersnew/common.inc.glsl"
#include "shadersnew/common_shadows_frag.inc.glsl"

// Uniforms for volume tiled lighting.
uniform samplerBuffer p3d_StaticLightBuffer;
uniform samplerBuffer p3d_DynamicLightBuffer;
uniform isamplerBuffer p3d_LightListBuffer;
uniform vec2 p3d_LensNearFar;
uniform vec2 p3d_WindowSize;
uniform vec3 p3d_LightLensDiv;
uniform vec2 p3d_LightLensZScaleBias;
#include "shadersnew/common_clustered_lighting.inc.glsl"

uniform sampler2D baseTexture;
#if BASETEXTURE2
uniform sampler2D baseTexture2;
#endif

#if DETAIL
uniform sampler2D detailSampler;
uniform vec2 detailParams;
uniform vec3 detailTint;
#define detailScale (detailParams.y)
#define detailBlendFactor (detailParams.x)
layout(constant_id = 9) const int DETAIL_BLEND_MODE = 0;
#endif

#if BUMPMAP || BUMPMAP2
#if BUMPMAP
uniform sampler2D normalTexture;
#endif
#if BUMPMAP2
uniform sampler2D normalTexture2;
#endif
layout(constant_id = 0) const bool SSBUMP = false;
#endif // BUMPMAP || BUMPMAP2

#if ENVMAP
uniform samplerCube envmapTexture;
#endif // ENVMAP

#if ENVMAP || PLANAR_REFLECTION
#if ENVMAPMASK
uniform sampler2D envmapMaskTexture;
#endif
uniform vec3 envmapTint;
uniform vec3 envmapContrast;
uniform vec3 envmapSaturation;
layout(constant_id = 1) const bool BASEALPHAENVMAPMASK = false;
layout(constant_id = 2) const bool NORMALMAPALPHAENVMAPMASK = false;
#endif // ENVMAP || PLANAR_REFLECTION

#if SUNLIGHT
uniform struct p3d_LightSourceParameters {
  vec4 color;
  vec4 direction;
} p3d_LightSource[1];
#if SUNLIGHT == 2
uniform sampler2DArrayShadow p3d_CascadeShadowMap;
in vec4 l_cascadeCoords[4];
layout(constant_id = 3) const int NUM_CASCADES = 0;
#endif
#endif // SUNLIGHT

#if FOG
uniform struct p3d_FogParameters {
  vec4 color;
  float density;
  float end;
  float scale;
} p3d_Fog;
layout(constant_id = 4) const int FOG_MODE = FM_linear;
layout(constant_id = 8) const int BLEND_MODE = 0;
#endif // FOG

#if ALPHA_TEST
layout(constant_id = 5) const int ALPHA_TEST_MODE = M_none;
layout(constant_id = 6) const float ALPHA_TEST_REF = 0.0;
#endif // ALPHA_TEST

#if SELFILLUM
uniform vec3 selfIllumTint;
#endif // SELFILLUM

#if PLANAR_REFLECTION
in vec4 l_texcoordReflection;
uniform sampler2D reflectionSampler;
#endif // PLANAR_REFLECTION

// Clip planes.
#if CLIPPING
uniform vec4 p3d_WorldClipPlane[4];
layout(constant_id = 7) const int NUM_CLIP_PLANES = 0;
#endif

#if LIGHTMAP
uniform sampler2D lightmapTextureL0;
uniform sampler2D lightmapTextureL1y;
uniform sampler2D lightmapTextureL1z;
uniform sampler2D lightmapTextureL1x;
#endif

in vec2 l_texcoord;
in vec2 l_texcoordLightmap;
in vec4 l_eyePos;
in vec4 l_vertexColor;
in vec4 l_worldPos;
in vec3 l_worldNormal;
in vec3 l_worldTangent;
in vec3 l_worldBinormal;
in vec3 l_worldVertexToEye;
in float l_vertexBlend;

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
#if !BUMPMAP && !BUMPMAP2
  return false;
#else
  return SSBUMP;
#endif
}

void
main() {
#if CLIPPING
  int clip_plane_count = min(4, NUM_CLIP_PLANES);
  for (int i = 0; i < clip_plane_count; ++i) {
    if (dot(p3d_WorldClipPlane[i], l_worldPos) < 0.0) {
      discard;
    }
  }
#endif

  float alpha = l_vertexColor.a;
  vec4 baseSample = texture(baseTexture, l_texcoord);
#if BASETEXTURE2
  baseSample = mix(baseSample, texture(baseTexture2, l_texcoord), vec4(l_vertexBlend));
#endif
#if DETAIL
  vec4 detailTexel = texture(detailSampler, l_texcoord * detailScale);
  detailTexel *= vec4(detailTint, 1.0);
  baseSample = texture_combine(baseSample, detailTexel, DETAIL_BLEND_MODE, detailBlendFactor);
#endif
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
#if BUMPMAP2
  vec4 normalTexel2 = texture(normalTexture2, l_texcoord);
#else
  vec4 normalTexel2 = vec4(0.5, 0.5, 1.0, 1.0);
#endif
  normalTexel = mix(normalTexel, normalTexel2, vec4(l_vertexBlend));

  vec3 tangentSpaceNormalUnnormalized;
  if (!hasSSBump()) {
    tangentSpaceNormalUnnormalized = 2.0 * normalTexel.xyz - 1.0;
  } else {
    tangentSpaceNormalUnnormalized = g_localBumpBasis[0] * normalTexel.x +
                                   g_localBumpBasis[1] * normalTexel.y +
                                   g_localBumpBasis[2] * normalTexel.z;
  }
  vec3 tangentSpaceNormal = normalize(tangentSpaceNormalUnnormalized);
  vec3 worldNormal = normalize(worldTangent * tangentSpaceNormal.x +
                               -worldBinormal * tangentSpaceNormal.y +
                               origWorldNormal * tangentSpaceNormal.z);// worldNormal = origWorldNormal;

  vec3 diffuseLighting = vec3(1.0);

#if LIGHTMAP
  vec3 sh[4];
  get_l1_lightmap_sample(lightmapTextureL0, lightmapTextureL1x,
    lightmapTextureL1y, lightmapTextureL1z, l_texcoordLightmap, sh);
  if (hasSSBump()) {
    // Evaluate the SH along each bump basis vector to get an equivalent
    // of RNM.  Then do the SS bump equation.

    // Generate world-space RNM basis vectors.
    vec3 dir1 = normalize(worldTangent * g_localBumpBasis[0].x +
                          -worldBinormal * g_localBumpBasis[0].y +
                          origWorldNormal * g_localBumpBasis[0].z);
    vec3 dir2 = normalize(worldTangent * g_localBumpBasis[1].x +
                          -worldBinormal * g_localBumpBasis[1].y +
                          origWorldNormal * g_localBumpBasis[1].z);
    vec3 dir3 = normalize(worldTangent * g_localBumpBasis[2].x +
                          -worldBinormal * g_localBumpBasis[2].y +
                          origWorldNormal * g_localBumpBasis[2].z);

    // Evaluate SH for each basis vector.
    vec3 col1 = eval_sh_l1(sh, dir1);
    vec3 col2 = eval_sh_l1(sh, dir2);
    vec3 col3 = eval_sh_l1(sh, dir3);

    // SS-bump lighting from RNM.
    diffuseLighting = col1 * normalTexel.x + col2 * normalTexel.y + col3 * normalTexel.z;

  } else {
    // Regular normal map route.  Just evaluate the SH for the single normal.
    diffuseLighting = eval_sh_l1(sh, worldNormal);
  }
#endif

  //o_color = vec4(diffuseLighting, 1);
  //return;

  float NdotL;

#if SUNLIGHT
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
#if SUNLIGHT == 2
    float sunShadowFactor = 0.0;
    GetSunShadow(sunShadowFactor, p3d_CascadeShadowMap, l_cascadeCoords, NdotL, NUM_CASCADES);
#else
    float sunShadowFactor = 1.0;
#endif
    vec3 light = p3d_LightSource[0].color.rgb * sunShadowFactor * NdotL;
    diffuseLighting += light;
  }
#endif // SUNLIGHT

  OPEN_ITERATE_CLUSTERED_LIGHTS()
    if (light_index < 0) {
      // Dynamic lights only.
      fetch_cluster_light(light_index, p3d_StaticLightBuffer, p3d_DynamicLightBuffer, light);

      vec3 toLight;
      float dist;
      if (light.type == LIGHT_TYPE_DIRECTIONAL) {
        toLight = light.direction;
        dist = 0;
      } else {
        toLight = light.pos - l_worldPos.xyz;
        dist = length(toLight);
        toLight = normalize(toLight);
      }
      if (hasSSBump()) {
        // Crazy SSBump NdotL method.
        vec3 tangentToLight;
        tangentToLight.x = dot(toLight, worldTangent);
        tangentToLight.y = dot(toLight, worldBinormal);
        tangentToLight.z = dot(toLight, origWorldNormal);
        tangentToLight = normalize(tangentToLight);
        NdotL = clamp(normalTexel.x * dot(tangentToLight, g_localBumpBasis[0]) +
                      normalTexel.y * dot(tangentToLight, g_localBumpBasis[1]) +
                      normalTexel.z * dot(tangentToLight, g_localBumpBasis[2]), 0.0, 1.0);
      } else {
        NdotL = max(0.0, dot(worldNormal, toLight));
      }
      float atten = 1.0;
      if (light.type != LIGHT_TYPE_DIRECTIONAL) {
        atten = 1.0 / (light.constant_atten + light.linear_atten * dist + light.quadratic_atten * dist * dist);
        atten *= (light.atten_radius > 0.0) ? (1.0 - (dist / light.atten_radius)) : 1.0;
        atten = max(0.0, atten);
        if (light.type == LIGHT_TYPE_SPOT && atten > 0.0) {
          float cosTheta = clamp(dot(toLight, -light.direction), 0, 1);
          float spotAtten = (cosTheta - light.spot_stopdot2) * light.spot_oodot;
          spotAtten = max(0.0001, spotAtten);
          spotAtten = pow(spotAtten, light.spot_exponent);
          spotAtten = clamp(spotAtten, 0, 1);
          atten *= spotAtten;
        }
      }
      diffuseLighting += light.color * NdotL * atten;
    }
  CLOSE_ITERATE_CLUSTERED_LIGHTS()

#if SELFILLUM
  diffuseLighting += selfIllumTint * albedo * baseSample.a;
#endif

  vec3 specularLighting = vec3(0.0);

#if ENVMAP || PLANAR_REFLECTION
  vec3 specMask = vec3(1.0);
  if (baseAlphaIsEnvMapMask()) {
    specMask *= 1.0 - baseSample.a;
  } else if (normalAlphaIsEnvMapMask()) {
    specMask *= normalTexel.a;
  }

#if ENVMAPMASK
  specMask *= texture(envmapMaskTexture, l_texcoord).rgb;
#endif

  float nDotV = dot(worldNormal, worldVertToEyeDir);

  float fresnel = 1.0 - nDotV;
  fresnel = pow(fresnel, 5.0);
  specMask *= fresnel;
  specMask *= envmapTint;

#if ENVMAP
  vec3 reflectVec = 2 * worldNormal * nDotV - worldVertToEyeDir;
  specularLighting += texture(envmapTexture, reflectVec).rgb * specMask;

#elif PLANAR_REFLECTION
  // Sample planar reflection.
  vec2 reflCoords = (l_texcoordReflection.xy + tangentSpaceNormal.xy) / l_texcoordReflection.w;
  specularLighting += texture(reflectionSampler, reflCoords).rgb * specMask;
#endif

#endif // ENVMAP

  vec3 diffuseComponent = albedo * diffuseLighting;

  vec3 result = diffuseComponent + specularLighting;

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
  o_color.rgb = do_fog(o_color.rgb, l_eyePos.xyz, fog_color,
                       p3d_Fog.density, p3d_Fog.end, p3d_Fog.scale,
                       FOG_MODE);
#endif
}
