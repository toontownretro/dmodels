#version 330

#pragma combo BASETEXTURE 0 1
#pragma combo SKINNING 0 1
#pragma combo PLANAR_REFLECTION 0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_vert.inc.glsl"

uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ProjectionMatrix;

uniform mat4 p3d_ModelMatrix;
uniform vec4 p3d_ColorScale;

in vec4 vertex;
in vec4 p3d_Color;

#if BASETEXTURE
uniform mat4 p3d_TextureTransform[1];
in vec4 texcoord;
out vec2 l_texcoord;
#endif

#if SKINNING
uniform mat4 p3d_TransformTable[120];
in vec4 transform_weight;
in uvec4 transform_index;
#endif

#if PLANAR_REFLECTION
out vec4 l_texcoordReflection;
const mat4 scale_mat = mat4(vec4(0.5, 0.0, 0.0, 0.0),
                            vec4(0.0, 0.5, 0.0, 0.0),
                            vec4(0.0, 0.0, 0.5, 0.0),
                            vec4(0.5, 0.5, 0.5, 1.0));
uniform vec3 wspos_view;
out vec3 l_worldVertexToEye;
out vec3 l_worldNormal;
in vec3 p3d_Normal;
#endif

out vec4 l_vertex_color;
out vec4 l_eye_position;
out vec4 l_world_position;

/**
 *
 */
void
main() {
  vec4 final_vertex = vertex;
  vec3 final_normal = vec3(0);
#if SKINNING
  do_skinning(vertex, vec3(0), p3d_TransformTable, transform_weight,
              transform_index, false, final_vertex, final_normal);
#endif

  vec4 world_pos = p3d_ModelMatrix * final_vertex;
  vec4 eye_pos = p3d_ViewMatrix * world_pos;
  gl_Position = p3d_ProjectionMatrix * eye_pos;

#if BASETEXTURE
  l_texcoord = (p3d_TextureTransform[0] * texcoord).xy;
#endif

  // Gamma to linear conversion on color.
  l_vertex_color.rgb = pow(p3d_Color.rgb, vec3(2.2)) * pow(p3d_ColorScale.rgb, vec3(2.2));
  l_vertex_color.a = p3d_Color.a * p3d_ColorScale.a;

  l_eye_position = eye_pos;
  l_world_position = world_pos;

#if PLANAR_REFLECTION
  l_texcoordReflection = scale_mat * gl_Position;
  l_worldVertexToEye = wspos_view - world_pos.xyz;
  l_worldNormal = normalize(mat3(p3d_ModelMatrix) * p3d_Normal);
#endif
}
