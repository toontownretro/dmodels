#version 430

uniform vec3 ambientProbe[9];

in vec3 l_normal;

out vec4 o_color;

#define COSINE_A0 (1.0)
#define COSINE_A1 (2.0 / 3.0)
#define COSINE_A2 (1.0 / 4.0)

void main() {
  vec3 normal = normalize(l_normal);

  vec3 color;
  color = ambientProbe[0] * 0.282095 * COSINE_A0;
  color += ambientProbe[1] * 0.488603 * normal.y * COSINE_A1;
  color += ambientProbe[2] * 0.488603 * normal.z * COSINE_A1;
  color += ambientProbe[3] * 0.488603 * normal.x * COSINE_A1;
  color += ambientProbe[4] * 1.092548 * normal.x * normal.y * COSINE_A2;
  color += ambientProbe[5] * 1.092548 * normal.y * normal.z * COSINE_A2;
  color += ambientProbe[6] * 0.315392 * (3.0 * normal.z * normal.z - 1.0) * COSINE_A2;
  color += ambientProbe[7] * 1.092548 * normal.x * normal.z * COSINE_A2;
  color += ambientProbe[8] * 0.546274 * (normal.x * normal.x - normal.y * normal.y) * COSINE_A2;

  o_color = vec4(color, 1.0);
}
