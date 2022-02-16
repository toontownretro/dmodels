#version 430

/**
 * @file eyes.vert.glsl
 * @author lachbr
 * @date 2021-03-24
 */

#extension GL_GOOGLE_include_directive : enable

#undef HAS_SHADOWED_LIGHT
#undef HAS_SHADOWED_POINT_LIGHT
#undef HAS_SHADOWED_SPOTLIGHT

#include "shaders/common_frag.inc.glsl"
#include "shaders/common_fog_frag.inc.glsl"

in vec2 l_texcoord;
in vec4 l_tangentViewVector;
in vec4 l_worldPosition_projPosZ;
in vec3 l_worldNormal;
in vec3 l_worldTangent;
in vec3 l_worldBinormal;
in vec4 l_vertexColor;
in vec4 l_eyePosition;

const float PI = 3.14159265359;

#ifdef LIGHTING

    uniform struct p3d_LightSourceParameters {
        vec4 color;
        vec4 position;
        vec4 direction;
        vec4 spotParams;
        vec3 attenuation;
    } p3d_LightSource[NUM_LIGHTS];

  #ifdef HAS_SHADOW_SUNLIGHT
      uniform sampler2D p3d_CascadeShadowMap;
      uniform mat4 p3d_CascadeMVPs[PSSM_SPLITS];
      in vec4 l_pssmCoords[PSSM_SPLITS];
  #endif

#endif // LIGHTING

#if AMBIENT_PROBE
  uniform vec3 ambientProbe[9];

#elif AMBIENT_LIGHT
    uniform struct {
      vec4 ambient;
    } p3d_LightModel;

#endif // AMBIENT_LIGHT

out vec4 outputColor;

uniform sampler2D corneaSampler;
uniform sampler2D irisSampler;
uniform samplerCube eyeReflectionCubemapSampler;
uniform sampler2D brdfLutSampler;
uniform sampler2D eyeAmbientOcclSampler;
uniform sampler2D lightwarpSampler;

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

  // Normalize it for energy conservation.
  // http://blog.stevemcauley.com/2011/12/03/energy-conserving-wrapped-diffuse/
  #ifdef HALFLAMBERT
    diff *= 0.5;
  #endif

  return diff;
}

// Accumulates lighting for the given light index.
void doLight(int i, inout vec3 lighting,
             vec3 worldNormal, vec3 worldPos, vec3 eyeDir, vec3 specularity, float roughness, vec3 albedo) {

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
                vec3 worldNormal, vec3 worldPos, vec3 eyeDir, vec3 specularity,
                float roughness, vec3 albedo,
                int numLights) {
  // Start diffuse at ambient color.
  for (int i = 0; i < numLights; i++) {
    doLight(i, lighting, worldNormal, worldPos, eyeDir,
            specularity, roughness, albedo);
  }
}

#endif // NUM_LIGHTS

void main() {
  vec3 worldNormal = normalize(l_worldNormal.xyz);
  vec3 worldTangent = normalize(l_worldTangent.xyz);
  vec3 worldBinormal = normalize(l_worldBinormal.xyz);

  vec3 tangentViewVector = l_tangentViewVector.xyz;

  vec3 worldPosition = l_worldPosition_projPosZ.xyz;

  vec3 worldViewVector = normalize(worldPosition.xyz - wspos_view.xyz);

  #ifdef RAYTRACESPHERE
  float dist = intersectRaySphere(wspos_view.xyz, worldViewVector, eyeOrigin[0], eyeballRadius);
  worldPosition.xyz = wspos_view.xyz + (worldViewVector * dist);
  if (dist == 0) {
    #ifdef RAYTRACEDISCARD
    discard; // discard to get a better silhouette
    #endif
    worldPosition.xyz = eyeOrigin[0].xyz + (worldNormal * eyeballRadius);
  }
  #endif

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

  //outputColor = vec4(irisColor.rgb * length(p3d_LightModel.ambient.rgb), 1);
  //return;

  // Iris lighting highlights
  vec3 irisLighting = vec3(0);

  // Mask off everything but the iris pixels
  float irisHighlightMask = texture(corneaSampler, corneaUv).a;

  // Generate the normal
  vec3 irisTangentNormal = corneaTangentNormal;
  irisTangentNormal.xy *= -2.5;

  vec3 totalRadiance = vec3(0);
  vec3 ambientLighting = vec3(0);
  vec3 specularity = vec3(0.04);
  float roughness = 0.2;

  // Do ligting
  #if defined(NUM_LIGHTS) && NUM_LIGHTS > 0
    doLighting(totalRadiance, corneaWorldNormal, worldPosition,
               -worldViewVector, specularity, roughness, irisColor.rgb, NUM_LIGHTS);
  #endif

  float NdotV = clamp(abs(dot(corneaWorldNormal, -worldViewVector)), 0, 1);

  vec3 diffuseIrradiance = ambientLookup(corneaWorldNormal);
  vec3 ambientLightingFresnel = fresnelSchlick(specularity, NdotV);
  vec3 diffuseContributionFactor = vec3(1.0) - ambientLightingFresnel;
  vec3 diffuseIBL = diffuseContributionFactor * irisColor.rgb * diffuseIrradiance;
  // Ambient occlusion
  vec3 ambientOcclFromTexture = texture(eyeAmbientOcclSampler, l_texcoord).rgb;
  vec3 ambientOcclColor = mix(ambientOcclColor, vec3(1.0), ambientOcclFromTexture.rgb);
  diffuseIBL *= ambientOcclColor;

  vec3 corneaReflectionVector = reflect(worldViewVector.xyz, corneaWorldNormal.xyz);
  vec3 specIrradiance = textureLod(eyeReflectionCubemapSampler, corneaReflectionVector.xyz, roughness * 9.0).rgb;
  vec3 specIBL = specIrradiance * envBRDFApprox(specularity, roughness, NdotV);
  ambientLighting = (diffuseIBL + specIBL);

  irisLighting += totalRadiance + ambientLighting;
  irisLighting += corneaNoise * 0.1;
  outputColor = vec4(irisLighting, 1);

  #ifdef FOG
		ApplyFog(outputColor, l_eyePosition);
  #endif

  FinalOutput(outputColor);
}
