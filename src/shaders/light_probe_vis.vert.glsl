#version 430

uniform mat4 p3d_ModelViewProjectionMatrix;
uniform mat4 p3d_ModelMatrix;

in vec4 p3d_Vertex;
in vec3 p3d_Normal;

out vec3 l_normal;

void main() {
  gl_Position = p3d_ModelViewProjectionMatrix * p3d_Vertex;
  l_normal = normalize((p3d_ModelMatrix * vec4(p3d_Normal, 0.0)).xyz);
}
