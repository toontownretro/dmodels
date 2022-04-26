#version 450

#pragma combo BASETEXTURE 0 1
#pragma combo SKINNING 0 2

/**
 * @file csmdepth.vert.glsl
 * @author lachbr
 * @date 2020-10-30
 */

#extension GL_GOOGLE_include_directive : enable
#extension GL_ARB_shader_viewport_layer_array : enable

#include "shadersnew/common_vert.inc.glsl"

uniform mat4 p3d_CascadeMVPs[4];

uniform mat4 p3d_ModelMatrix;
uniform vec4 p3d_ColorScale;

in vec4 p3d_Vertex;
in vec4 p3d_Color;
in vec2 texcoord;

out vec3 v_texcoord_alpha;
out vec4 v_worldPosition;

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

  // First move into world space.
  vec4 worldPos = p3d_ModelMatrix * finalVertex;
  // Then multiply by the cascade's view-projection matrix.
  gl_Position = p3d_CascadeMVPs[gl_InstanceID] * worldPos;

  gl_Layer = gl_InstanceID;

  float alpha = p3d_ColorScale.a * p3d_Color.a
    #if !BASETEXTURE
    * baseColor.a
    #endif
    ;
  v_texcoord_alpha = vec3(texcoord, alpha);

  v_worldPosition = worldPos;
}
