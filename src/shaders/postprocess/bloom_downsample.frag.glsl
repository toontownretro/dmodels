#version 430

uniform sampler2D sourceTexture;
uniform writeonly image2D destTexture;

uniform ivec2 mipVec;
#define mip (mipVec.x)

void main() {
  ivec2 intCoord = ivec2(gl_FragCoord.xy);

  vec2 parentTexSize = vec2(textureSize(sourceTexture, mip).xy);
  vec2 texelSize = 1.0 / parentTexSize;

  // Compute the floating point coordinate pointing to the exact center of the
  // parent texel center.
  vec2 fltCoord = vec2(intCoord + 0.5) / parentTexSize * 2.0;

  // Filter the image, see:
  // http://fs5.directupload.net/images/151213/qfnexcls.png
  vec3 centerSample = textureLod(sourceTexture, fltCoord, mip).rgb;

  // inner samples (marked red)
  vec3 sample_r_tl = textureLod(sourceTexture, fltCoord + vec2(-1, 1) * texelSize, mip).rgb;
  vec3 sample_r_tr = textureLod(sourceTexture, fltCoord + vec2(1, 1) * texelSize, mip).rgb;
  vec3 sample_r_bl = textureLod(sourceTexture, fltCoord + vec2(-1, -1) * texelSize, mip).rgb;
  vec3 sample_r_br = textureLod(sourceTexture, fltCoord + vec2(1, -1) * texelSize, mip).rgb;

  // corner samples
  vec3 sample_t = textureLod(sourceTexture, fltCoord + vec2(0, 2) * texelSize, mip).rgb;
  vec3 sample_r = textureLod(sourceTexture, fltCoord + vec2(2, 0) * texelSize, mip).rgb;
  vec3 sample_b = textureLod(sourceTexture, fltCoord + vec2(0, -2) * texelSize, mip).rgb;
  vec3 sample_l = textureLod(sourceTexture, fltCoord + vec2(-2, 0) * texelSize, mip).rgb;

  // edge samples
  vec3 sample_tl = textureLod(sourceTexture, fltCoord + vec2(-2, 2) * texelSize, mip).rgb;
  vec3 sample_tr = textureLod(sourceTexture, fltCoord + vec2(2, 2) * texelSize, mip).rgb;
  vec3 sample_bl = textureLod(sourceTexture, fltCoord + vec2(-2, -2) * texelSize, mip).rgb;
  vec3 sample_br = textureLod(sourceTexture, fltCoord + vec2(2, -2) * texelSize, mip).rgb;

  vec3 kernelSumRed = (sample_r_tl + sample_r_tr + sample_r_bl + sample_r_br);
  vec3 kernelSumYellow = (sample_tl + sample_t + sample_l + centerSample);
  vec3 kernelSumGreen = (sample_tr + sample_t + sample_r + centerSample);
  vec3 kernelSumPurple = (sample_bl + sample_b + sample_l + centerSample);
  vec3 kernelSumBlue = (sample_br + sample_b + sample_r + centerSample);

  vec3 summedKernel = kernelSumRed * 0.5 + kernelSumYellow * 0.125 +
                      kernelSumGreen * 0.125 + kernelSumPurple * 0.125 +
                      kernelSumBlue * 0.125;

  // Since every sub-kernel has 4 samples, normalize that.
  summedKernel *= 0.25;

  // Decay.
  summedKernel *= 1.3;

  imageStore(destTexture, intCoord, vec4(summedKernel, 0.0));
}
