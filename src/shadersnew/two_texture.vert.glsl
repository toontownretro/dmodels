#version 330

#pragma combo SKINNING 0 2
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
uniform vec3 sineXParams;
#define sineXMin (sineXParams.x)
#define sineXMax (sineXParams.y)
#define sineXPeriod (sineXParams.z)
uniform vec3 sineYParams;
#define sineYMin (sineYParams.x)
#define sineYMax (sineYParams.y)
#define sineYPeriod (sineYParams.z)

uniform vec4 p3d_ColorScale;
in vec4 p3d_Color;

#if SKINNING
uniform mat4 p3d_TransformTable[120];
in vec4 transform_weight;
in uvec4 transform_index;
#if SKINNING == 2
in vec4 transform_weight2;
in uvec4 transform_index2;
#endif
#endif

out vec4 l_eyePos;
out vec4 l_worldPos;

uniform float osg_FrameTime;

const float PI = 3.14159265359;
float doSine(in float period, in float smin, in float smax) {
  float value = (sin(2.0 * PI * (osg_FrameTime - 0.0) / period) * 0.5) + 0.5;
  value = (smax - smin) * value + smin;
  return value;
}

void
main() {
  vec4 finalVertex = p3d_Vertex;
#if SKINNING == 1
  vec3 foo = vec3(0);
  vec3 foo2 = vec3(0);
  vec3 foo3 = vec3(0);
  do_skinning(p3d_Vertex, vec3(0), vec3(0), vec3(0), p3d_TransformTable, transform_weight, transform_index,
              finalVertex, foo, foo2, foo3);
#elif SKINNING == 2
  vec3 foo = vec3(0);
  vec3 foo2 = vec3(0);
  vec3 foo3 = vec3(0);
  do_skinning8(p3d_Vertex, vec3(0), vec3(0), vec3(0), p3d_TransformTable, transform_weight, transform_weight2,
               transform_index, transform_index2, finalVertex, foo, foo2, foo3);
#endif

  vec4 worldPos = p3d_ModelMatrix * finalVertex;
  vec4 eyePos = p3d_ViewMatrix * worldPos;
  gl_Position = p3d_ProjectionMatrix * eyePos;

  l_eyePos = eyePos;
  l_worldPos = worldPos;

  l_texcoord = (baseTextureTransform * vec4(texcoord, 1, 1)).xy;
  l_texcoord += baseTextureScroll * osg_FrameTime;
  l_texcoord.x += doSine(sineXPeriod, sineXMin, sineXMax);
  l_texcoord.y += doSine(sineYPeriod, sineYMin, sineYMax);

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
