#version 330

#pragma combo SKINNING 0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_vert.inc.glsl"

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

// Vertex shader inputs.
in vec4 p3d_Vertex;
in vec3 p3d_Normal;
in vec4 p3d_Color;
in vec3 p3d_Tangent;
in vec3 p3d_Binormal;
in vec2 texcoord;
#if SKINNING
in vec4 transform_weight;
in uvec4 transform_index;
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

void
main() {
  vec4 animated_vertex = p3d_Vertex;
  vec3 animated_normal = p3d_Normal;
#if SKINNING
  do_skinning(p3d_Vertex, p3d_Normal, p3d_TransformTable, transform_weight,
              transform_index, true, animated_vertex, animated_normal);
#endif

  vec4 world_pos = p3d_ModelMatrix * animated_vertex;
  vec4 eye_pos = p3d_ViewMatrix * world_pos;

  // Output final clip-space vertex position for GL.
  gl_Position = p3d_ProjectionMatrix * eye_pos;

  l_texcoord = texcoord;

  // Calculate world-space vertex information.
  l_world_pos = world_pos;
  l_world_vertex_to_eye = wspos_view - world_pos.xyz;
  l_world_normal = normalize((p3d_ModelMatrix * vec4(animated_normal, 0.0)).xyz);
  l_world_tangent = normalize(mat3(p3d_ModelMatrix) * p3d_Tangent);
  l_world_binormal = normalize(mat3(p3d_ModelMatrix) * p3d_Binormal);

  vec4 vertex_color = p3d_Color;
  vertex_color.rgb = pow(vertex_color.rgb, vec3(2.2));
  vec4 color_scale = p3d_ColorScale;
  color_scale.rgb = pow(color_scale.rgb, vec3(2.2));
  l_vertex_color = vertex_color * color_scale;

  l_eye_pos = eye_pos;
}
