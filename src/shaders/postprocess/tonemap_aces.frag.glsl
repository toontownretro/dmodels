#version 430

in vec2 l_texcoord;

uniform sampler2D sceneTexture;

out vec4 o_color;

const mat3 aces_input_mat = mat3(
  vec3(0.59719, 0.35458, 0.04823),
  vec3(0.07600, 0.90834, 0.01566),
  vec3(0.02840, 0.13383, 0.83777)
);

const mat3 aces_output_mat = mat3(
  vec3(1.60475, -0.53108, -0.07367),
  vec3(-0.10208,  1.10813, -0.00605),
  vec3(-0.00327, -0.07276,  1.07602)
);

vec3 rtt_and_odt_fit(vec3 v) {
  vec3 a = v * (v + 0.0245786) - 0.000090537;
  vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
  return a / b;
}

float aces(float x) {
  const float a = 2.51;
  const float b = 0.03;
  const float c = 2.43;
  const float d = 0.59;
  const float e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
  o_color = textureLod(sceneTexture, l_texcoord, 0);
  //o_color.rgb = pow(o_color.rgb, vec3(0.833));
  //o_color.rgb *= 1.07;
  o_color.rgb = vec3(aces(o_color.r), aces(o_color.g), aces(o_color.b));
  //o_color.rgb = o_color.rgb * aces_input_mat;
  //o_color.rgb = rtt_and_odt_fit(o_color.rgb);
  //o_color.rgb = clamp(o_color.rgb * aces_output_mat, 0, 1);
}
