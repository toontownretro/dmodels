#version 430

in vec2 l_texcoord;

uniform sampler2D sceneTexture;
uniform sampler2D bloomTexture;

out vec4 o_color;

void main() {
  o_color = textureLod(sceneTexture, l_texcoord, 0);
  o_color.rgb += textureLod(bloomTexture, l_texcoord, 0).rgb;
}
