// Depth-only shader for z-prepass or shadow maps.
// Does alpha cutouts.

#version 330

#pragma combo BASETEXTURE 0 1
#pragma combo SKINNING 0 2

/**
 * @file depth.vert.glsl
 * @author brian
 * @date 2020-12-16
 */

#extension GL_GOOGLE_include_directive : enable

#include "shadersnew/common_vert.inc.glsl"

uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ProjectionMatrix;
uniform mat4 p3d_ModelMatrix;
uniform vec4 p3d_ColorScale;

in vec4 p3d_Vertex;
in vec4 p3d_Color;
in vec2 texcoord;

out vec3 l_texcoord_alpha;
out vec4 l_worldPosition;

#if !BASETEXTURE
uniform vec4 baseColor;
#endif

#if SKINNING
uniform mat4 p3d_TransformTable[120];
in vec4 transform_weight;
in uvec4 transform_index;
#if SKINNING == 2
in vec4 transform_weight2;
in uvec4 transform_index2;
#endif
#endif

void main() {
  vec4 finalVertex = p3d_Vertex;

#if SKINNING == 1
  vec3 foo = vec3(0);
  do_skinning(p3d_Vertex, vec3(0), p3d_TransformTable, transform_weight, transform_index,
              false, finalVertex, foo);
#elif SKINNING == 2
  vec3 foo = vec3(0);
  do_skinning8(p3d_Vertex, vec3(0), p3d_TransformTable, transform_weight, transform_weight2,
               transform_index, transform_index2, false, finalVertex, foo);
#endif

  vec4 worldPos = p3d_ModelMatrix * finalVertex;
  vec4 eyePos = p3d_ViewMatrix * worldPos;
  gl_Position = p3d_ProjectionMatrix * eyePos;

  float alpha = p3d_ColorScale.a * p3d_Color.a
    #if !BASETEXTURE
    * baseColor.a
    #endif
    ;
  l_texcoord_alpha = vec3(texcoord, alpha);

  l_worldPosition = worldPos;
}
