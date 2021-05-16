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

void main() {
  o_color = textureLod(sceneTexture, l_texcoord, 0);
  o_color.rgb = aces_input_mat * o_color.rgb;
  o_color.rgb = rtt_and_odt_fit(o_color.rgb);
  o_color.rgb = aces_output_mat * o_color.rgb;
}
