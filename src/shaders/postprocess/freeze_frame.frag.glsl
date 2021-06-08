#version 330

uniform sampler2D freezeFrameSampler;

in vec2 l_texcoord;

out vec3 outputColor;

void main() {
  outputColor = texture(freezeFrameSampler, l_texcoord).rgb;
}
