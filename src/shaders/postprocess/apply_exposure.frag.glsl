#version 430

in vec2 l_texcoord;

uniform sampler2D sceneTexture;
uniform float p3d_ExposureScale;

out vec4 o_color;

void main() {
  o_color = textureLod(sceneTexture, l_texcoord, 0) * 10000;
  o_color.rgb *= p3d_ExposureScale;
}
