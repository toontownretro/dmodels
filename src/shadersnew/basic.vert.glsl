#version 330

#pragma combo BASETEXTURE 0 1
#pragma combo SKINNING 0 2
#pragma combo PLANAR_REFLECTION 0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_vert.inc.glsl"

uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ProjectionMatrix;

uniform mat4 p3d_ModelMatrix;
uniform vec4 p3d_ColorScale;

in vec4 vertex;
in vec4 p3d_Color;
in vec3 p3d_Normal;
in vec3 p3d_Tangent;
in vec3 p3d_Binormal;

#if BASETEXTURE
uniform mat4 p3d_TextureTransform[1];
in vec4 texcoord;
out vec2 l_texcoord;
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

#if PLANAR_REFLECTION
out vec4 l_texcoordReflection;
const mat4 scale_mat = mat4(vec4(0.5, 0.0, 0.0, 0.0),
                            vec4(0.0, 0.5, 0.0, 0.0),
                            vec4(0.0, 0.0, 0.5, 0.0),
                            vec4(0.5, 0.5, 0.5, 1.0));
uniform vec3 wspos_view;
out vec3 l_worldVertexToEye;
#endif

out vec4 l_vertex_color;
out vec4 l_eye_position;
out vec4 l_world_position;
out vec3 l_worldNormal;

/**
 *
 */
void
main() {
  vec4 final_vertex = vertex;
  vec3 final_normal = p3d_Normal;
  vec3 final_tangent = p3d_Tangent;
  vec3 final_binormal = p3d_Binormal;
#if SKINNING == 2
  do_skinning8(vertex, p3d_Normal, p3d_Tangent, p3d_Binormal,
               p3d_TransformTable, transform_weight, transform_weight2, transform_index, transform_index2,
               final_vertex, final_normal, final_tangent, final_binormal);
#elif SKINNING == 1
  do_skinning(vertex, p3d_Normal, p3d_Tangent, p3d_Binormal,
              p3d_TransformTable, transform_weight, transform_index,
              final_vertex, final_normal, final_tangent, final_binormal);
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

  l_worldNormal = normalize(mat3(p3d_ModelMatrix) * p3d_Normal);

#if PLANAR_REFLECTION
  l_texcoordReflection = scale_mat * gl_Position;
  l_worldVertexToEye = wspos_view - world_pos.xyz;
#endif
}
