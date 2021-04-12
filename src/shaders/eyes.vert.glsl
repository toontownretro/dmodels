#version 330

/**
 * @file eyes.vert.glsl
 * @author lachbr
 * @date 2021-03-24
 */

#extension GL_GOOGLE_include_directive : enable

#include "shaders/common_animation_vert.inc.glsl"
#include "shaders/common_shadows_vert.inc.glsl"
#include "shaders/common.inc.glsl"

uniform mat4 p3d_ModelViewProjectionMatrix;
uniform vec4 p3d_ColorScale;
uniform mat4 p3d_ModelMatrix;
uniform mat4 p3d_ModelViewMatrix;
uniform vec4 wspos_view;

uniform vec3 eyeOrigin[1];
uniform vec4 irisProjectionU[1];
uniform vec4 irisProjectionV[1];

in vec4 p3d_Vertex;
in vec4 p3d_Color;
in vec4 texcoord;

out vec2 l_texcoord;
out vec4 l_tangentViewVector;
out vec4 l_worldPosition_projPosZ;
out vec3 l_worldNormal;
out vec3 l_worldTangent;
out vec3 l_worldBinormal;
out vec4 l_vertexColor;
out vec4 l_eyePosition;

#if defined(HAS_SHADOW_SUNLIGHT)
    uniform struct p3d_LightSourceParameters {
        vec4 color;
        vec4 position;
        vec4 direction;
        vec4 spotParams;
        vec3 attenuation;
    } p3d_LightSource[NUM_LIGHTS];

    uniform mat4 p3d_CascadeMVPs[PSSM_SPLITS];
    out vec4 l_pssmCoords[PSSM_SPLITS];
#endif

void main() {
  vec4 finalVertex = p3d_Vertex;

  #if HAS_HARDWARE_SKINNING
    vec3 foo = vec3(0);
    DoHardwareAnimation(finalVertex, finalNormal, p3d_Vertex, foo);
  #endif

  gl_Position = p3d_ModelViewProjectionMatrix * finalVertex;

  l_texcoord = texcoord.xy;

  l_eyePosition = p3d_ModelViewMatrix * finalVertex;

  vec3 eyeSocketUpVector = normalize(-irisProjectionV[0].xyz);
  vec3 eyeSocketLeftVector = normalize(-irisProjectionU[0].xyz);

  vec4 worldPosition = p3d_ModelMatrix * finalVertex;
  l_worldPosition_projPosZ.xyz = worldPosition.xyz;
  l_worldPosition_projPosZ.w = gl_Position.z;

  // Normal = (Pos - Eye origin)
  vec3 worldNormal = normalize(worldPosition.xyz - eyeOrigin[0].xyz);
  l_worldNormal.xyz = worldNormal.xyz;

  // Tangent & Binormal
  vec3 worldTangent = normalize(cross(eyeSocketUpVector, worldNormal));
  l_worldTangent.xyz = worldTangent;

  vec3 worldBinormal = normalize(cross(worldNormal, worldTangent));
  l_worldBinormal.xyz = worldBinormal;

  vec3 worldViewVector = normalize(worldPosition.xyz - wspos_view.xyz);
  l_tangentViewVector.xyz = WorldToTangentNormalized(worldViewVector, worldNormal, worldTangent, worldBinormal);

  float normalDotSizeVec = -dot(worldNormal, eyeSocketLeftVector) * 0.5;
  vec3 bentWorldNormal = normalize(normalDotSizeVec * eyeSocketLeftVector + worldNormal);

  vec4 vertexColor = p3d_Color;
  vec4 colorScale = p3d_ColorScale;
  GammaToLinear(vertexColor);
  GammaToLinear(colorScale);
  l_vertexColor = vertexColor * colorScale;

  #ifdef HAS_SHADOW_SUNLIGHT
    ComputeSunShadowPositions(worldNormal, worldPosition,
                            p3d_LightSource[PSSM_LIGHT_ID].direction.xyz,
                            p3d_CascadeMVPs, l_pssmCoords);
  #endif
}
