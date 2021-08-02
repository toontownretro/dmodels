//
// Builds a log-luminance histogram from the scene render target.
//

#version 430

#define NUM_HISTOGRAM_BINS 256

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

uniform sampler2D sceneImage;
layout(r32ui) uniform uimage1D histogram;

uniform vec2 minLogLum_ooLogLumRange;
#define minLogLum (minLogLum_ooLogLumRange.x)
#define ooLogLumRange (minLogLum_ooLogLumRange.y)

shared uint localHistogram[NUM_HISTOGRAM_BINS];

const vec3 luminance_weights = vec3(0.2125, 0.7154, 0.0721);

uint colorToHistogramBin(vec3 color) {
  float luminance = dot(color, luminance_weights);

  // Avoid taking log2 of 0.
  luminance = max(0.001, luminance);

  const float K = 12.5;
  float ev = log2(luminance * 100.0 / K);

  float logLuminance = clamp((ev - minLogLum) * ooLogLumRange, 0, 1);
  return uint(logLuminance * 254.0 + 1.0);
}

void main() {
  //if (gl_LocalInvocationIndex < NUM_HISTOGRAM_BINS) {
    localHistogram[gl_LocalInvocationIndex] = 0;
  //}

  barrier();

  uvec2 size = textureSize(sceneImage, 0).xy;

  if (gl_GlobalInvocationID.x < size.x && gl_GlobalInvocationID.y < size.y) {
    vec3 color = texelFetch(sceneImage, ivec2(gl_GlobalInvocationID.xy), 0).rgb;
    uint binIndex = colorToHistogramBin(color);
    if (binIndex > 0) {
      atomicAdd(localHistogram[binIndex], 1);
    }

  }

  barrier();

  //if (gl_LocalInvocationIndex < NUM_HISTOGRAM_BINS) {
    imageAtomicAdd(histogram, int(gl_LocalInvocationIndex), localHistogram[gl_LocalInvocationIndex]);
  //}
}
