#version 430

/**
 * @file eyes.vert.glsl
 * @author lachbr
 * @date 2021-03-24
 */

#extension GL_GOOGLE_include_directive : enable

#pragma combo DIRECT_LIGHT 0 1
#pragma combo AMBIENT_LIGHT 0 2
#pragma combo RAYTRACESPHERE 0 1
#pragma combo RAYTRACEDISCARD 0 1
#pragma combo FOG 0 1

#pragma skip $[and $[not $[RAYTRACESPHERE]],$[RAYTRACEDISCARD]]

#include "shadersnew/common_frag.inc.glsl"

in vec2 l_texcoord;
in vec4 l_tangentViewVector;
in vec4 l_worldPosition_projPosZ;
in vec3 l_worldNormal;
in vec3 l_worldTangent;
in vec3 l_worldBinormal;
in vec4 l_vertexColor;
in vec4 l_eyePosition;

#if DIRECT_LIGHT
uniform struct p3d_LightSourceParameters {
    vec4 color;
    vec4 position;
    vec4 direction;
    vec4 spotParams;
    vec3 attenuation;
} p3d_LightSource[4];
layout(constant_id = 0) const int NUM_LIGHTS = 0;
#endif // DIRECT_LIGHT

#if AMBIENT_LIGHT == 1
uniform struct {
  vec4 ambient;
} p3d_LightModel;
#elif AMBIENT_LIGHT == 2
uniform vec3 ambientProbe[9];
#endif // AMBIENT_LIGHT

#if FOG
uniform struct p3d_FogParameters {
  vec4 color;
  float density;
  float end;
  float scale;
} p3d_Fog;
layout(constant_id = 1) const int FOG_MODE = FM_linear;
#endif // FOG

out vec4 outputColor;

uniform sampler2D corneaSampler;
uniform sampler2D irisSampler;
uniform samplerCube eyeReflectionCubemapSampler;
uniform sampler2D eyeAmbientOcclSampler;
uniform sampler1D lightwarpSampler;

uniform vec4 packedConst0;
#define dilationFactor (packedConst0.x)
#define glossiness (packedConst0.y)
#define averageAmbient (packedConst0.z)
#define corneaBumpStrength (packedConst0.w)

uniform vec4 packedConst1;
#define eyeballRadius (packedConst1.y)
#define parallaxStrength (packedConst1.w)

uniform vec3 ambientOcclColor;

// These are dynamic inputs filled in by the eye node.
uniform vec3 eyeOrigin[1];
uniform vec4 irisProjectionU[1];
uniform vec4 irisProjectionV[1];

uniform vec4 wspos_view;

// Ray sphere intersect returns distance along ray to intersection ================================
float intersectRaySphere(vec3 cameraPos, vec3 ray, vec3 sphereCenter, float sphereRadius) {
  vec3 dst = cameraPos.xyz - sphereCenter.xyz;
  float B = dot(dst, ray);
  float C = dot(dst, dst) - (sphereRadius * sphereRadius);
  float D = B*B - C;
  return (D > 0) ? (-B * sqrt(D)) : 0;
}

vec3 ambientLookup(vec3 wnormal) {
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

vec3 diffuseTerm(float NdotL) {
  float result;
  result = clamp(NdotL, 0, 1);
  vec3 diff = vec3(result);
  diff = 2.0 * texture(lightwarpSampler, result).rgb;
  return diff;
}

void specularAndRimTerms(inout vec3 specularLighting, vec3 lightDir, vec3 eyeDir,
                         vec3 worldNormal, float specularExponent, vec3 color) {
  vec3 vReflect = 2 * worldNormal * dot(worldNormal, eyeDir) - eyeDir;
  float NdotH = clamp(dot(vReflect, lightDir), 0, 1);
  specularLighting = vec3(pow(NdotH, specularExponent));

  float NdotL = max(0.0, dot(worldNormal, lightDir));

  specularLighting *= NdotL;
  specularLighting *= color;
}

// Accumulates lighting for the given light index.
void doLight(int i, inout vec3 diffuseLighting, inout vec3 specularLighting,
             vec3 worldNormal, vec3 worldPos, vec3 eyeDir, float specularExponent) {

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

  float fNdotL;

  vec3 L;
  if (isDirectional) {
    L = lightDir;

    fNdotL = max(0.0, dot(L, worldNormal));

  } else {
    L = lightPos - worldPos;
    lightDist = max(0.00001, length(L));
    L = normalize(L);

    fNdotL = max(0.0, dot(L, worldNormal));

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

  vec3 NdotL = diffuseTerm(fNdotL);

  diffuseLighting += lightColor * lightAtten * NdotL;

  vec3 localSpecular = vec3(0.0);
  specularAndRimTerms(localSpecular, L, eyeDir, worldNormal, specularExponent,
                      lightColor * lightAtten);
  specularLighting += localSpecular;
}

void doLighting(inout vec3 diffuseLighting, inout vec3 specularLighting,
                vec3 worldNormal, vec3 worldPos, vec3 eyeDir, float specularExponent,
                int numLights) {
  // Start diffuse at ambient color.
  for (int i = 0; i < numLights; i++) {
    doLight(i, diffuseLighting, specularLighting, worldNormal, worldPos,
            eyeDir, specularExponent);
  }
}

#endif // DIRECT_LIGHT

void main() {
  vec3 worldNormal = normalize(l_worldNormal.xyz);
  vec3 worldTangent = normalize(l_worldTangent.xyz);
  vec3 worldBinormal = normalize(l_worldBinormal.xyz);

  vec3 tangentViewVector = l_tangentViewVector.xyz;

  vec3 worldPosition = l_worldPosition_projPosZ.xyz;

  vec3 worldViewVector = normalize(worldPosition.xyz - wspos_view.xyz);

#if RAYTRACESPHERE
  float dist = intersectRaySphere(wspos_view.xyz, worldViewVector, eyeOrigin[0], eyeballRadius);
  worldPosition.xyz = wspos_view.xyz + (worldViewVector * dist);
  if (dist == 0) {
#if RAYTRACEDISCARD
    discard; // discard to get a better silhouette
#endif
    worldPosition.xyz = eyeOrigin[0].xyz + (worldNormal * eyeballRadius);
  }
#endif // RAYTRACESPHERE

  vec2 corneaUv = vec2(0);
  corneaUv.x = dot(irisProjectionU[0], vec4(worldPosition, 1.0));
  corneaUv.y = dot(irisProjectionV[0], vec4(worldPosition, 1.0));

  vec2 sphereUv = (corneaUv * 0.5) + 0.25;

  // Parallax mapping on iris
  float irisOffset = texture(corneaSampler, corneaUv).b;
  vec2 parallaxVector = vec2(0);//(tangentViewVector.xy * irisOffset * parallaxStrength) / max(0.00001, (1.0 - tangentViewVector.z));
  //parallaxVector.x = -parallaxVector.x;

  vec2 irisUv = sphereUv - parallaxVector;

  vec2 corneaNoiseUv = sphereUv + (parallaxVector * 0.5);
  float corneaNoise = texture(irisSampler, corneaNoiseUv).a;

  // Cornea normal
  // Sample 2D normal from texture
  vec3 corneaTangentNormal = vec3(0, 0, 1);
  vec4 corneaSample = texture(corneaSampler, corneaUv);
  corneaTangentNormal.xy = corneaSample.rg - 0.5;

  // Scale strength of normal
  corneaTangentNormal.xy *= corneaBumpStrength;

  // Add in surface noise and imperfections.
  corneaTangentNormal.xy += corneaNoise * 0.1;

  // Normalize tangent vector
  corneaTangentNormal = normalize(corneaTangentNormal);

  //outputColor = vec4(corneaTangentNormal.rgb * 0.5 + 0.5, 1);
  //return;

  // Transform into world space
  //vec3 corneaWorldNormal = worldTangent * corneaTangentNormal.x;
  //vec3 corneaWorldNormal = normalize(worldTangent * corneaTangentNormal.x + worldBinormal * corneaTangentNormal.y + worldNormal * corneaTangentNormal.z);
  //vec3 corneaWorldNormal = TangentToWorldNormalized(corneaTangentNormal, worldNormal, worldTangent, worldBinormal);
  //outputColor = vec4(corneaWorldNormal * 0.5 + 0.5, 1.0);
  //return;

  vec3 corneaWorldNormal = worldNormal;

  // Dilate pupil
  irisUv -= 0.5; // center around (0, 0)
  float pupilCenterToBorder = clamp(length(irisUv) / 0.2, 0, 1);
  float pupilDilateFactor = dilationFactor;
  irisUv *= mix(1.0, pupilCenterToBorder, clamp(pupilDilateFactor, 0, 1) * 2.5 - 1.25);
  irisUv += 0.5;

  // Iris color
  vec4 irisColor = texture(irisSampler, irisUv);

  // Mask off everything but the iris pixels
  float irisHighlightMask = texture(corneaSampler, corneaUv).a;

  // Generate the normal
  vec3 irisTangentNormal = corneaTangentNormal;
  irisTangentNormal.xy *= -2.5;

  vec3 diffuseLighting = ambientLookup(corneaWorldNormal);
  // Modulate ambient by ambient occlusion texture.
  vec3 ambientOcclFromTexture = texture(eyeAmbientOcclSampler, l_texcoord).rgb;
  vec3 ambientOccl = mix(ambientOcclColor, vec3(1.0), ambientOcclFromTexture.rgb);
  diffuseLighting *= ambientOccl;

  vec3 specularLighting = vec3(0);

#if DIRECT_LIGHT
  // Calculate diffuse and specular contribution from local light sources.
  float specularExponent = 1.0 + 149.0 * glossiness;
  doLighting(diffuseLighting, specularLighting, corneaWorldNormal, worldPosition,
             -worldViewVector, specularExponent, NUM_LIGHTS);
#endif

  // Cube map specular.
  vec3 corneaReflectionVector = reflect(worldViewVector.xyz, corneaWorldNormal.xyz);
  specularLighting += texture(eyeReflectionCubemapSampler, corneaReflectionVector.xyz).rgb;

  // Sum lighting components.
  vec3 diffuseComponent = diffuseLighting * irisColor.rgb;
  vec3 result = diffuseComponent + specularLighting;
  result += corneaNoise * 0.1;

  outputColor = vec4(result, 1.0);

#if FOG
	outputColor.rgb = do_fog(outputColor.rgb, l_eyePosition.xyz, p3d_Fog.color.rgb,
                           p3d_Fog.density, p3d_Fog.end, p3d_Fog.scale,
                           FOG_MODE);
#endif // FOG
}
