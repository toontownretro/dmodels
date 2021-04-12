#version 330

#extension GL_GOOGLE_include_directive : enable
#include "shaders/common_sequences.inc.glsl"

in vec2 l_texcoord;

uniform sampler2D texSampler;
uniform vec2 blurDirection;
uniform vec2 resolution;
uniform vec3 scaleFactor;

out vec4 outputColor;

void main()
{
  outputColor = blur13(texSampler, l_texcoord, resolution, blurDirection);
	outputColor.xyz *= scaleFactor.xyz;
}
