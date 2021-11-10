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

#include "shaders/common_lighting_frag.inc.glsl"
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

#ifdef LIGHTING

    uniform struct p3d_LightSourceParameters {
        vec4 color;
        vec4 position;
        vec4 direction;
        vec4 spotParams;
        vec3 attenuation;
    } p3d_LightSource[NUM_LIGHTS];

  #ifdef HAS_SHADOW_SUNLIGHT
      uniform sampler2DArray p3d_CascadeShadowMap;
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
  vec2 parallaxVector = vec2(0, 0);//(tangentViewVector.xy * irisOffset * parallaxStrength) / (1.0 - tangentViewVector.z);
  //parallaxVector.x = -parallaxVector.x;

  vec2 irisUv = sphereUv - parallaxVector;

  vec2 corneaNoiseUv = sphereUv + (parallaxVector * 0.5);
  float corneaNoise = texture(irisSampler, corneaNoiseUv).a;

  // Cornea normal
  // Sample 2D normal from texture
  vec3 corneaTangentNormal = vec3(0, 0, 1);
  vec4 corneaSample = texture(corneaSampler, corneaUv);
  //outputColor = vec4(corneaSample.rgb * length(p3d_LightModel.ambient.rgb), 1);
  //return;
  corneaTangentNormal.xy = corneaSample.rg - 0.5;

  // Scale strength of normal
  corneaTangentNormal.xy *= corneaBumpStrength;

  // Add in surface noise and imperfections.
  corneaTangentNormal.xy += corneaNoise * 0.1;

  // Normalize tangent vector
  corneaTangentNormal = normalize(corneaTangentNormal);

  // Transform into world space
  //vec3 corneaWorldNormal = worldTangent * corneaTangentNormal.x;
  vec3 corneaWorldNormal = TangentToWorldNormalized(corneaTangentNormal, worldNormal, worldTangent, worldBinormal);
  //outputColor = vec4(corneaWorldNormal, 1.0);
  //return;

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

  // !!!!!!!!!!!!!!!!!!!!!PBR Cornea lighting!!!!!!!!!!!!!!!!!!!!!!
  float NdotV = max(0.0, dot(corneaWorldNormal.xyz, normalize(worldViewVector.xyz)));
  float perceptualRoughness = clamp(pow(1 - glossiness, 3.5), 0, 1);
  float roughness = perceptualRoughness * perceptualRoughness;
  float metalness = 0.0;
  vec3 specularColor = mix(vec3(0.04), irisColor.rgb, metalness);
  #ifdef LIGHTING

    // Initialize our lighting parameters
    LightingParams_t params = newLightingParams_t(
        vec4(worldPosition.xyz, 1),
        normalize(worldViewVector.xyz),
        normalize(corneaWorldNormal.xyz),
        NdotV,
        roughness,
        metalness,
        specularColor,
        1.0,
        irisColor.rgb
        );

    vec3 ambientDiffuse = vec3(0, 0, 0);
    #if defined(AMBIENT_PROBE)
        vec3 wnormal = corneaWorldNormal;
        const float c1 = 0.429043;
        const float c2 = 0.511664;
        const float c3 = 0.743125;
        const float c4 = 0.886227;
        const float c5 = 0.247708;
        ambientDiffuse += (c1 * ambientProbe[8] * (wnormal.x * wnormal.x - wnormal.y * wnormal.y) +
                c3 * ambientProbe[6] * wnormal.z * wnormal.z +
                c4 * ambientProbe[0] -
                c5 * ambientProbe[6] +
                2.0 * c1 * ambientProbe[4] * wnormal.x * wnormal.y +
                2.0 * c1 * ambientProbe[7] * wnormal.x * wnormal.z +
                2.0 * c1 * ambientProbe[5] * wnormal.y * wnormal.z +
                2.0 * c2 * ambientProbe[3] * wnormal.x +
                2.0 * c2 * ambientProbe[1] * wnormal.y +
                2.0 * c2 * ambientProbe[2] * wnormal.z);
    #elif defined(AMBIENT_LIGHT)
        ambientDiffuse += p3d_LightModel.ambient.rgb;
    #endif

    // Now factor in local light sources
    for (int i = 0; i < NUM_LIGHTS; i++)
    {
            params.lColor = p3d_LightSource[i].color;
            bool isDirectional = p3d_LightSource[i].color.w == 1.0;
            bool isSpot = p3d_LightSource[i].direction.w == 1.0;
            bool isPoint = (!isDirectional && !isSpot);
            params.lPos = p3d_LightSource[i].position;
            params.lDir = normalize(p3d_LightSource[i].direction);
            params.lAtten = vec4(p3d_LightSource[i].attenuation, 0.0);
            params.lSpotParams = p3d_LightSource[i].spotParams;

        if (isDirectional)
        {
            GetDirectionalLight(params
                                #ifdef HAS_SHADOW_SUNLIGHT
                                    , p3d_CascadeShadowMap, l_pssmCoords,
                                    p3d_CascadeMVPs, wspos_view.xyz,
                                    worldPosition.xyz
                                #endif // HAS_SHADOW_SUNLIGHT
            );
        }
        else if (isPoint)
        {
            GetPointLight(params);
        }
        else if (isSpot)
        {

            GetSpotlight(params);
        }
    }

    vec3 totalRadiance = max(vec3(0), params.totalRadiance);

  #else // LIGHTING

      // No direct lighting.  Just give it the ambient if we have it.
      #ifdef AMBIENT_LIGHT
          vec3 ambientDiffuse = p3d_LightModel.ambient.rgb;
      #else
          // No direct or ambient lighting.  Make it fullbright.
          vec3 ambientDiffuse = vec3(1.0);
      #endif
      vec3 totalRadiance = vec3(0);

  #endif // LIGHTING

  // Ambient occlusion
  vec3 ambientOcclFromTexture = texture(eyeAmbientOcclSampler, l_texcoord).rgb;
  vec3 ambientOcclColor = mix(ambientOcclColor, vec3(1.0), ambientOcclFromTexture.rgb);
  ambientDiffuse *= ambientOcclColor;

  vec3 corneaReflectionVector = reflect(worldViewVector.xyz, corneaWorldNormal.xyz);
  vec3 reflection = texture(eyeReflectionCubemapSampler, corneaReflectionVector.xyz).rgb;
  #ifdef AMBIENT_LIGHT
    reflection *= length(p3d_LightModel.ambient.rgb);
  #endif
  vec2 specularBRDF = texture(brdfLutSampler, vec2(NdotV, perceptualRoughness)).xy;
  reflection *= (specularColor * specularBRDF.x + specularBRDF.y);

  ambientDiffuse *= irisColor.rgb;

  irisLighting += totalRadiance + ambientDiffuse;
  irisLighting += corneaNoise * 0.1;
  irisLighting += reflection.rgb;
  outputColor = vec4(irisLighting, 1);

  #ifdef FOG
		ApplyFog(outputColor, l_eyePosition);
  #endif

  FinalOutput(outputColor);
}
