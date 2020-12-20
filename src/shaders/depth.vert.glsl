#version 330

/**
 * @file depth.vert.glsl
 * @author lachbr
 * @date 2020-12-16
 */

#extension GL_GOOGLE_include_directive : enable

#include "shaders/common_animation_vert.inc.glsl"

uniform mat4 p3d_ModelViewProjectionMatrix;
uniform vec4 p3d_ColorScale;

in vec4 p3d_Vertex;
in vec4 p3d_Color;
in vec2 texcoord;

out vec3 l_texcoord_alpha;

#ifdef NEED_WORLD_POSITION
uniform mat4 p3d_ModelMatrix;
out vec4 l_worldPosition;
#endif

void main() {
  vec4 finalVertex = p3d_Vertex;
  #if HAS_HARDWARE_SKINNING
    // Animate the vertex first.
    vec3 foo = vec3(0);
    DoHardwareAnimation(finalVertex, foo, p3d_Vertex, foo);
  #endif

  gl_Position = p3d_ModelViewProjectionMatrix * finalVertex;
  #ifdef NEED_WORLD_POSITION
    l_worldPosition = p3d_ModelMatrix * finalVertex;
  #endif
  l_texcoord_alpha = vec3(texcoord, p3d_ColorScale.a * p3d_Color.a);
}
