#version 430

#pragma combo BLAH 0 1

in vec4 p3d_Vertex;
in vec3 p3d_Normal;
in vec3 p3d_Tangent;
in vec3 p3d_Binormal;
in vec2 texcoord_lightmap;

uniform mat4 p3d_ModelMatrix;
uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ProjectionMatrix;
uniform vec4 wspos_view;

out vec2 l_texcoord_lightmap;
out vec4 l_texcoord_reflection;
out vec2 l_texcoord;
out vec3 l_world_normal;
out vec3 l_world_eye_to_vert;
out vec3 l_world_tangent;
out vec3 l_world_binormal;

void
main() {
  vec4 world_pos = p3d_ModelMatrix * p3d_Vertex;
  vec4 eye_pos = p3d_ViewMatrix * world_pos;
  gl_Position = p3d_ProjectionMatrix * eye_pos;

  mat4 scale_mat = mat4(vec4(0.5, 0.0, 0.0, 0.0),
                        vec4(0.0, 0.5, 0.0, 0.0),
                        vec4(0.0, 0.0, 0.5, 0.0),
                        vec4(0.5, 0.5, 0.5, 1.0));
  l_texcoord_lightmap = texcoord_lightmap;
  l_texcoord_reflection = scale_mat * gl_Position;
  l_texcoord = vec2(p3d_Vertex.x * 0.5 + 0.5, p3d_Vertex.y * 0.5 + 0.5);
  l_world_normal = normalize((p3d_ModelMatrix * vec4(p3d_Normal, 0)).xyz);
  l_world_eye_to_vert = (wspos_view - world_pos).xyz;
  l_world_tangent = mat3(p3d_ModelMatrix) * p3d_Tangent.xyz;
  l_world_binormal = mat3(p3d_ModelMatrix) * -p3d_Binormal.xyz;
}
