#version 330

uniform sampler2D sceneColorSampler;

in vec2 l_texcoord;

out vec4 outputColor;

void main() {
  outputColor = texture(sceneColorSampler, l_texcoord);
}
