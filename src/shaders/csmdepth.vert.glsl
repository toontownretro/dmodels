#version 330

/**
 * @file csmdepth.vert.glsl
 * @author lachbr
 * @date 2020-10-30
 */

#extension GL_GOOGLE_include_directive : enable

#include "shaders/common_animation_vert.inc.glsl"

uniform mat4 p3d_CascadeMVPs[NUM_SPLITS];
uniform mat4 p3d_ModelMatrix;
uniform vec4 p3d_ColorScale;

in vec4 p3d_Vertex;
in vec4 p3d_Color;
in vec2 texcoord;

out vec3 v_texcoord_alpha;
out int v_instanceID;
out vec4 v_worldPosition;

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

  v_texcoord_alpha = vec3(texcoord, p3d_ColorScale.a * p3d_Color.a);
  v_instanceID = gl_InstanceID;
  v_worldPosition = worldPos;
}
