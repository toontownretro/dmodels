#version 330

uniform sampler2D sceneColorSampler;

in vec2 l_texcoord;

out vec3 outputColor;

void main() {
  outputColor = texture(sceneColorSampler, l_texcoord).rgb;
}
