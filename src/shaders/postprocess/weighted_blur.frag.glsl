/**
 * Seperable gaussian blur weighted by pixel normal and depth.
 */

#version 330

const float gaussian_weights_7[7] = float[7](0.199675627498, 0.176213122789, 0.121109390075, 0.0648251851385, 0.0270231576029, 0.00877313479159, 0.00221819585465);

uniform sampler2D depthSampler;
uniform sampler2D normalSampler;
uniform sampler2D colorSampler;

uniform ivec2 blurDirection;
uniform ivec2 screenSize;
uniform vec3 pixelStretch_normalFactor_depthFactor;

#define pixelStretch (pixelStretch_normalFactor_depthFactor.x)
#define normalFactor (pixelStretch_normalFactor_depthFactor.y)
#define depthFactor (pixelStretch_normalFactor_depthFactor.z)

in vec2 l_texcoord;

out vec4 outputColor;

vec3 SampleNormal(vec2 texcoord) {
  return normalize(textureLod(normalSampler, texcoord, 0).xyz * 2 - 1);
}

void main() {
  vec2 pixelSize = 1.0 * pixelStretch / vec2(screenSize.x, screenSize.y);

  vec4 accum = vec4(0);
  float accumW = 0.0;

  // Amount of samples.
  const int blurSize = 7;

  // Get the mid pixel normal and depth
  vec3 pixelNorm = SampleNormal(l_texcoord);
  float pixelDepth = textureLod(depthSampler, l_texcoord, 0).x;

  // Blur to the right and left
  for (int i = -blurSize + 1; i < blurSize; i++) {
    vec2 offcoord = l_texcoord + pixelSize * i * blurDirection;
    vec4 sampled = textureLod(colorSampler, offcoord, 0);
    vec3 norm = SampleNormal(offcoord);
    float depth = textureLod(depthSampler, offcoord, 0).x;

    float weight = gaussian_weights_7[abs(i)];

    // Weight by normal and depth.
    weight *= 1.0 - clamp(normalFactor * distance(norm, pixelNorm) * 1.0, 0, 1);
    weight *= 1.0 - clamp(depthFactor * abs(depth - pixelDepth) * 3, 0, 1);

    accum += sampled * weight;
    accumW += weight;
  }

  accum /= max(0.04, accumW);

  outputColor = accum;
}
