#version 430

// This is a shader that mimics Source Engine's VertexLitGeneric shader for
// compatibility with TF2's materials.

#extension GL_GOOGLE_include_directive : enable
#include "shaders/common_animation_vert.inc.glsl"

in vec4 p3d_Vertex;
in vec3 p3d_Normal;
in vec4 p3d_Color;
in vec3 p3d_Tangent;
in vec3 p3d_Binormal;
in vec2 texcoord;

uniform mat4 p3d_ModelViewProjectionMatrix;
uniform mat4 p3d_ModelMatrix;
uniform vec4 p3d_ColorScale;
uniform vec3 wspos_view;

out vec2 l_texcoord;
out vec3 l_worldPosition;
out vec3 l_worldNormal;
out vec3 l_worldTangent;
out vec3 l_worldBinormal;
out vec4 l_vertexColor;
// Un-normalized vector from world-space vertex position to
// world-space camera position.
out vec3 l_worldVertexToEye;

//#if FOG
// Position of vertex relative to camera.  Needed for fog.
out vec3 l_eyePosition;
uniform mat4 p3d_ModelViewMatrix;
//#endif

void main() {
  // First animate the vertex using the joint transforms.
  vec4 finalVertex = p3d_Vertex;
  vec3 finalNormal = p3d_Normal;
  DoHardwareAnimation(finalVertex, finalNormal, p3d_Vertex, p3d_Normal);

  // Output final clip-space vertex position for GL.
  gl_Position = p3d_ModelViewProjectionMatrix * finalVertex;

  // Pass on texture coordinates for interpolation and texture
  // sampling in fragment shader.
  l_texcoord = texcoord;

  // Calculate world-space vertex information.
  l_worldPosition = (p3d_ModelMatrix * finalVertex).xyz;
  l_worldNormal = normalize((p3d_ModelMatrix * vec4(finalNormal, 0.0)).xyz);
  l_worldVertexToEye = wspos_view - l_worldPosition;
  l_worldTangent = normalize(mat3(p3d_ModelMatrix) * p3d_Tangent);
  l_worldBinormal = normalize(mat3(p3d_ModelMatrix) * p3d_Binormal);

  // Gamma-correct vertex color and color scale and pass it on for
  // fragment interpolation.
  vec4 vertexColor = p3d_Color;
  vertexColor.rgb = pow(vertexColor.rgb, vec3(2.2));
  vec4 colorScale = p3d_ColorScale;
  colorScale.rgb = pow(colorScale.rgb, vec3(2.2));
  l_vertexColor = vertexColor * colorScale;

//#if FOG
  l_eyePosition = (p3d_ModelViewMatrix * finalVertex).xyz;
//#endif
}
