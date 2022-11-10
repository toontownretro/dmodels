#version 330

#pragma combo SKINNING 0 2
#pragma combo HAS_SHADOW_SUNLIGHT 0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_vert.inc.glsl"
#include "shadersnew/common_shadows_vert.inc.glsl"

// Per-view uniforms.
uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ProjectionMatrix;
uniform vec3 wspos_view;

// Per-object uniforms.
uniform mat4 p3d_ModelMatrix;
#if SKINNING
uniform mat4 p3d_TransformTable[120];
#endif

// Per-material uniforms.
uniform vec4 p3d_ColorScale;

#if HAS_SHADOW_SUNLIGHT
uniform struct p3d_LightSourceParameters {
  vec4 color;
  vec4 position;
  vec4 direction;
  vec4 spotParams;
  vec3 attenuation;
} p3d_LightSource[4];
uniform mat4 p3d_CascadeMVPs[4];
out vec4 l_cascadeCoords[4];
layout(constant_id = 0) const int CSM_LIGHT_ID = 0;
layout(constant_id = 1) const int NUM_CASCADES = 0;
#endif

// Vertex shader inputs.
in vec4 p3d_Vertex;
in vec3 p3d_Normal;
in vec4 p3d_Color;
in vec3 p3d_Tangent;
in vec3 p3d_Binormal;
in vec2 texcoord;
in vec3 vertex_lighting;
#if SKINNING
in vec4 transform_weight;
in uvec4 transform_index;
#if SKINNING == 2
in vec4 transform_weight2;
in uvec4 transform_index2;
#endif
#endif

// Vertex shader outputs/pixel shader inputs.
out vec4 l_world_pos;
out vec3 l_world_normal;
out vec3 l_world_tangent;
out vec3 l_world_binormal;
// Un-normalized vector from world-space vertex position to
// world-space camera position.
out vec3 l_world_vertex_to_eye;
out vec4 l_vertex_color;
out vec4 l_eye_pos;
out vec2 l_texcoord;
out vec3 l_vertex_light;

layout(constant_id = 2) const bool BAKED_VERTEX_LIGHT = false;

uniform mat4 baseTextureTransform;

void
main() {
  vec4 animated_vertex = p3d_Vertex;
  vec3 animated_normal = p3d_Normal;
#if SKINNING == 1
  do_skinning(p3d_Vertex, p3d_Normal, p3d_TransformTable, transform_weight,
              transform_index, true, animated_vertex, animated_normal);
#elif SKINNING == 2
  do_skinning8(p3d_Vertex, p3d_Normal, p3d_TransformTable, transform_weight, transform_weight2,
               transform_index, transform_index2, true, animated_vertex, animated_normal);
#endif

  vec4 world_pos = p3d_ModelMatrix * animated_vertex;
  vec4 eye_pos = p3d_ViewMatrix * world_pos;

  // Output final clip-space vertex position for GL.
  gl_Position = p3d_ProjectionMatrix * eye_pos;

  l_texcoord = (baseTextureTransform * vec4(texcoord, 1, 1)).xy;

  // Calculate world-space vertex information.
  l_world_pos = world_pos;
  l_world_vertex_to_eye = wspos_view - world_pos.xyz;
  l_world_normal = normalize((p3d_ModelMatrix * vec4(animated_normal, 0.0)).xyz);
  l_world_tangent = normalize((p3d_ModelMatrix * vec4(p3d_Tangent, 0.0)).xyz);
  l_world_binormal = normalize((p3d_ModelMatrix * vec4(-p3d_Binormal, 0.0)).xyz);

  if (BAKED_VERTEX_LIGHT) {
    l_vertex_light = vertex_lighting;
  } else {
    l_vertex_light = vec3(1.0);
  }

  vec4 vertex_color = p3d_Color;
  vertex_color.rgb = pow(vertex_color.rgb, vec3(2.2));
  vec4 color_scale = p3d_ColorScale;
  color_scale.rgb = pow(color_scale.rgb, vec3(2.2));
  l_vertex_color = vertex_color * color_scale;

  l_eye_pos = eye_pos;

#if HAS_SHADOW_SUNLIGHT
  ComputeSunShadowPositions(l_world_normal, l_world_pos,
                            p3d_LightSource[CSM_LIGHT_ID].direction.xyz,
                            p3d_CascadeMVPs, l_cascadeCoords, NUM_CASCADES);
#endif // HAS_SHADOW_SUNLIGHT
}
