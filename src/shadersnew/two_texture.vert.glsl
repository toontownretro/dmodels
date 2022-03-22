#version 330

#pragma combo SKINNING 0 1
#pragma combo LIGHTMAP 0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_vert.inc.glsl"

uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ProjectionMatrix;

uniform mat4 p3d_ModelMatrix;

in vec4 p3d_Vertex;
in vec2 texcoord;

out vec2 l_texcoord;
out vec2 l_texcoord2;

out vec4 l_vertexColor;

#if LIGHTMAP
in vec2 texcoord_lightmap;
out vec2 l_texcoordLightmap;
#endif // LIGHTMAP

uniform mat4 baseTextureTransform;
uniform mat4 baseTexture2Transform;
uniform vec4 textureScroll;
#define baseTextureScroll (textureScroll.xy)
#define baseTexture2Scroll (textureScroll.zw)

uniform vec4 p3d_ColorScale;
in vec4 p3d_Color;

#if SKINNING
uniform mat4 p3d_TransformTable[120];
in vec4 transform_weight;
in uvec4 transform_index;
#endif

out vec4 l_eyePos;
out vec4 l_worldPos;

uniform float osg_FrameTime;

void
main() {
  vec4 finalVertex = p3d_Vertex;
#if SKINNING
  vec3 foo = vec3(0);
  do_skinning(p3d_Vertex, vec3(0), p3d_TransformTable, transform_weight,
              transform_index, false, finalVertex, foo);
#endif // SKINNING

  vec4 worldPos = p3d_ModelMatrix * finalVertex;
  vec4 eyePos = p3d_ViewMatrix * worldPos;
  gl_Position = p3d_ProjectionMatrix * eyePos;

  l_eyePos = eyePos;
  l_worldPos = worldPos;

  l_texcoord = (baseTextureTransform * vec4(texcoord, 1, 1)).xy;
  l_texcoord += baseTextureScroll * osg_FrameTime;
  l_texcoord2 = (baseTexture2Transform * vec4(texcoord, 1, 1)).xy;
  l_texcoord2 += baseTexture2Scroll * osg_FrameTime;

#if LIGHTMAP
  l_texcoordLightmap = texcoord_lightmap;
#endif

  vec4 vertexColor = p3d_Color;
  vertexColor.rgb = pow(vertexColor.rgb, vec3(2.2));
  vec4 colorScale = p3d_ColorScale;
  colorScale.rgb = pow(colorScale.rgb, vec3(2.2));
  l_vertexColor = vertexColor * colorScale;
}
