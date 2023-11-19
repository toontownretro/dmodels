//
// Calculates the average luminance from the histogram computing in
// build_histogram.compute.glsl.
//

#version 430

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

uniform sampler2D sceneImage;
coherent layout(r32ui) uniform uimage1D histogram;
layout(r32f) uniform image1D luminanceOutput;
uniform float osg_DeltaFrameTime;

uniform vec2 minLogLum_logLumRange;
#define minLogLum (minLogLum_logLumRange.x)
#define logLumRange (minLogLum_logLumRange.y)

shared float localHistogram[256];

void main() {
  float countForThisBin = float(imageLoad(histogram, int(gl_LocalInvocationIndex)));
  localHistogram[gl_LocalInvocationIndex] = countForThisBin * float(gl_LocalInvocationIndex);

  ivec2 sceneImageSize = textureSize(sceneImage, 0);
  float pixelCount = float(sceneImageSize.x * sceneImageSize.y);

  barrier();

  // Reset the bucket in anticipation of next pass.
  //imageStore(histogram, int(gl_LocalInvocationIndex), uvec4(0));

  for (uint i = (256 >> 1); i > 0; i >>= 1) {
    if (gl_LocalInvocationIndex < i) {
      localHistogram[gl_LocalInvocationIndex] += localHistogram[gl_LocalInvocationIndex + i];
    }

    barrier();
  }

  if (gl_GlobalInvocationID == 0) {
    // Compute a target exposure value.
    float weightedLogAverage = (localHistogram[0] / max(pixelCount - countForThisBin, 1.0)) - 1.0;
    // Map from our histogram space to actual luminance
    float weightedAvgLum = ((weightedLogAverage / 254.0) * logLumRange) + minLogLum;
    imageStore(luminanceOutput, 0, vec4(weightedAvgLum));
  }
}


