#version 330

/**
 * @file csmdepth.vert.glsl
 * @author lachbr
 * @date 2020-10-30
 */

#extension GL_GOOGLE_include_directive : enable

#include "shaders/common_animation_vert.inc.glsl"

uniform mat4 p3d_CascadeMVPs[NUM_SPLITS];
uniform vec4 p3d_CascadeAtlasMinMax[NUM_SPLITS];
uniform vec2 p3d_CascadeAtlasScale[NUM_SPLITS];

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

out vec2 l_clipPosition;
flat out vec4 atlasMinMax;

float remapVal(float val, float A, float B, float C, float D) {
  float cVal = (val - A) / (B - A);
  //cVal = clamp(cVal, 0.0, 1.0);
  return C + (D - C) * cVal;
}

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

  // Shift and scale vertex into cascade atlas region.
  gl_Position.x = remapVal(gl_Position.x, -1, 1, p3d_CascadeAtlasMinMax[gl_InstanceID].x * 2 - 1, p3d_CascadeAtlasMinMax[gl_InstanceID].y * 2 - 1);
  gl_Position.y = remapVal(gl_Position.y, -1, 1, p3d_CascadeAtlasMinMax[gl_InstanceID].z * 2 - 1, p3d_CascadeAtlasMinMax[gl_InstanceID].w * 2 - 1);

  l_clipPosition = gl_Position.xy * 0.5 + 0.5;
  atlasMinMax = p3d_CascadeAtlasMinMax[gl_InstanceID];
  //l_instanceID = gl_InstanceID;

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
