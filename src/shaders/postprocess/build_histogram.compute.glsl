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

int colorToHistogramBin(vec3 color) {
  float luminance = dot(color, luminance_weights) * 10000;

  // Calculate the log_2 luminance and express it as a value in [0.0, 1.0]
  // where 0.0 represents the minimum luminance, and 1.0 represents the max.
  float logLum = clamp((log2(luminance) - minLogLum) * ooLogLumRange, 0.0, 1.0);

  // Ignore pixels out of range?
  //if (logLum < 0.0 || logLum > 1.0) {
  //  return -1;
  //}

  return clamp(int(logLum * 256.0), 0, 255);
}

void main() {
  localHistogram[gl_LocalInvocationIndex] = 0;
  barrier();

  uvec2 size = textureSize(sceneImage, 0).xy;

  vec2 fsize = vec2(size);
  vec2 center = fsize / 2.0;

  if (gl_GlobalInvocationID.x < size.x && gl_GlobalInvocationID.y < size.y) {
    vec2 coord = vec2(gl_GlobalInvocationID.xy);
    float w = 1.0 - smoothstep(0.0, 1.0, (distance(coord, center) / (fsize.y * 0.5)));
    vec3 color = texelFetch(sceneImage, ivec2(gl_GlobalInvocationID.xy), 0).rgb;
    int binIndex = colorToHistogramBin(color);
    if (binIndex >= 0) {
      atomicAdd(localHistogram[uint(binIndex)], int(w * 100.0));
    }

  }

  barrier();

  imageAtomicAdd(histogram, int(gl_LocalInvocationIndex), localHistogram[gl_LocalInvocationIndex]);
}
