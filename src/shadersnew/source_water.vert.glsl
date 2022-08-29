#version 430

#pragma combo BLAH 0 1

in vec4 p3d_Vertex;
in vec3 p3d_Normal;
in vec3 p3d_Tangent;
in vec3 p3d_Binormal;
in vec2 texcoord_lightmap;
in vec2 texcoord;

uniform mat4 p3d_ModelMatrix;
uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ProjectionMatrix;
uniform vec4 wspos_view;

out vec2 l_texcoord_lightmap;
out vec2 l_texcoord;
out vec4 l_proj_pos;
out vec4 l_reflectxy_refractyx;
out vec3 l_world_normal;
out vec3 l_world_tangent;
out vec3 l_world_binormal;
out vec3 l_world_vertex_to_eye;
out vec3 l_eye_pos;
out float l_w;

void
main() {
  vec4 world_pos = p3d_ModelMatrix * p3d_Vertex;
  vec4 eye_pos = p3d_ViewMatrix * world_pos;
  l_eye_pos = eye_pos.xyz;
  gl_Position = p3d_ProjectionMatrix * eye_pos;

  l_proj_pos = gl_Position;

  mat4 view_proj = p3d_ViewMatrix * p3d_ProjectionMatrix;

  vec2 proj_tangent = (view_proj * vec4(p3d_Tangent, 0)).xy;
  vec2 proj_binormal = (view_proj * vec4(-p3d_Binormal, 0)).xy;

  vec2 reflect_pos = (l_proj_pos.xy + l_proj_pos.w) * 0.5;

  vec2 refract_pos = (l_proj_pos.xy + l_proj_pos.w) * 0.5;//vec2(l_proj_pos.x, -l_proj_pos.y);
  //refract_pos = (refract_pos + l_proj_pos.w) * 0.5;

  l_reflectxy_refractyx = vec4(reflect_pos.x, reflect_pos.y, refract_pos.x, refract_pos.y);

  l_texcoord = texcoord * 0.007;// * 10;
  l_texcoord_lightmap = texcoord_lightmap;

  l_w = l_proj_pos.w;

  l_world_normal = normalize((p3d_ModelMatrix * vec4(p3d_Normal, 0)).xyz);
  l_world_tangent = normalize((p3d_ModelMatrix * vec4(p3d_Tangent, 0)).xyz);
  l_world_binormal = normalize((p3d_ModelMatrix * vec4(-p3d_Binormal, 0)).xyz);
  l_world_vertex_to_eye = wspos_view.xyz - world_pos.xyz;
}
