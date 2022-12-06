#version 330

#pragma combo SUNLIGHT 0 1
#pragma combo PLANAR_REFLECTION 0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_shadows_vert.inc.glsl"

uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ProjectionMatrix;
uniform vec3 wspos_view;

uniform mat4 p3d_ModelMatrix;
uniform vec4 p3d_ColorScale;

in vec4 p3d_Vertex;
in vec3 p3d_Normal;
in vec3 p3d_Tangent;
in vec3 p3d_Binormal;
in vec4 p3d_Color;
in vec2 texcoord;
in vec2 texcoord_lightmap;
in uint blend;

out vec4 l_worldPos;
out vec3 l_worldNormal;
out vec3 l_worldTangent;
out vec3 l_worldBinormal;
out vec3 l_worldVertexToEye;
out vec4 l_eyePos;
out vec4 l_vertexColor;
out vec2 l_texcoord;
out vec2 l_texcoordLightmap;
out float l_vertexBlend;

#if SUNLIGHT
// We only need the direction, but uniform has to match
// pixel shader.
uniform struct p3d_LightSourceParameters {
  vec4 color;
  vec4 direction;
} p3d_LightSource[1];
uniform mat4 p3d_CascadeMVPs[4];
out vec4 l_cascadeCoords[4];
layout(constant_id = 0) const int NUM_CASCADES = 0;
#endif // SUNLIGHT

#if PLANAR_REFLECTION
out vec4 l_texcoordReflection;
const mat4 scale_mat = mat4(vec4(0.5, 0.0, 0.0, 0.0),
                            vec4(0.0, 0.5, 0.0, 0.0),
                            vec4(0.0, 0.0, 0.5, 0.0),
                            vec4(0.5, 0.5, 0.5, 1.0));
#endif

void
main() {
  vec4 worldPos = p3d_ModelMatrix * p3d_Vertex;
  vec4 eyePos = p3d_ViewMatrix * worldPos;
  gl_Position = p3d_ProjectionMatrix * eyePos;

  l_worldPos = worldPos;
  l_worldNormal = normalize((p3d_ModelMatrix * vec4(p3d_Normal, 0.0)).xyz);
  l_worldTangent = normalize((p3d_ModelMatrix * vec4(p3d_Tangent, 0.0)).xyz);
  l_worldBinormal = normalize((p3d_ModelMatrix * vec4(-p3d_Binormal, 0.0)).xyz);
  l_worldVertexToEye = wspos_view - worldPos.xyz;
  l_eyePos = eyePos;

  l_texcoord = texcoord;
  l_texcoordLightmap = texcoord_lightmap;

  vec4 vertexColor = p3d_Color;
  vertexColor.rgb = pow(vertexColor.rgb, vec3(2.2));
  vec4 colorScale = p3d_ColorScale;
  colorScale.rgb = pow(colorScale.rgb, vec3(2.2));
  l_vertexColor = vertexColor * colorScale;

  l_vertexBlend = float(blend) / 255.0;

#if SUNLIGHT
  ComputeSunShadowPositions(l_worldNormal, l_worldPos,
                            p3d_LightSource[0].direction.xyz,
                            p3d_CascadeMVPs, l_cascadeCoords,
                            NUM_CASCADES);
#endif // SUNLIGHT

#if PLANAR_REFLECTION
  l_texcoordReflection = scale_mat * gl_Position;
#endif
}
