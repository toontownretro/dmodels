#version 450

/**
 * @file csmdepth.vert.glsl
 * @author lachbr
 * @date 2020-10-30
 */

#extension GL_GOOGLE_include_directive : enable
#extension GL_ARB_shader_viewport_layer_array : enable

#include "shaders/common_animation_vert.inc.glsl"

uniform mat4 p3d_CascadeMVPs[NUM_SPLITS];

uniform mat4 p3d_ModelMatrix;
uniform vec4 p3d_ColorScale;

in vec4 p3d_Vertex;
in vec4 p3d_Color;
in vec2 texcoord;

out vec3 v_texcoord_alpha;

#ifdef NEED_WORLD_POSITION
out vec4 v_worldPosition;
#endif

#ifndef BASETEXTURE
uniform vec4 baseColor;
#endif

void main() {
  vec4 finalVertex = p3d_Vertex;
  #if HAS_HARDWARE_SKINNING
    vec3 foo = vec3(0);
    DoHardwareAnimation(finalVertex, foo, p3d_Vertex, foo);
  #endif

  // First move into world space.
  vec4 worldPos = p3d_ModelMatrix * finalVertex;
  // Then multiply by the cascade's view-projection matrix.
  gl_Position = p3d_CascadeMVPs[gl_InstanceID] * worldPos;

  gl_Layer = gl_InstanceID;

  float alpha = p3d_ColorScale.a * p3d_Color.a
    #ifndef BASETEXTURE
    * baseColor.a
    #endif
    ;
  v_texcoord_alpha = vec3(texcoord, alpha);

  #ifdef NEED_WORLD_POSITION
    v_worldPosition = worldPos;
  #endif
}
