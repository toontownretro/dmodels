#version 430

#pragma optionNV (unroll all)
#extension GL_GOOGLE_include_directive : enable

#include "shaders/common_sequences.inc.glsl"

in vec2 l_texcoord;

uniform sampler2D sourceTexture;

out vec3 o_color;

const vec3 Y = vec3(0.2125, 0.7154, 0.0721);

float getWeight(vec3 color, float weight) {
  return weight / (1.0 + dot(color, Y));
}

void main() {
  float weights = 0.0;
  vec3 accum = vec3(0);
  const int filterSize = 2;

  vec2 texelOfs = vec2(1.0) / vec2(textureSize(sourceTexture, 0).xy);

  // Find all surrounding pixels and weight them.
  for (int i = -filterSize; i <= filterSize; i++) {
    for (int j = -filterSize; j <= filterSize; j++) {
      vec3 colorSample = textureLod(sourceTexture, l_texcoord + vec2(i, j) * texelOfs, 0).rgb;
      float weight = getWeight(colorSample, gaussian_weights_3[abs(i)] * gaussian_weights_3[abs(j)]);
      accum += colorSample * weight;
      weights += weight;
    }
  }

  accum /= max(0.01, weights);
  o_color = accum;
}
