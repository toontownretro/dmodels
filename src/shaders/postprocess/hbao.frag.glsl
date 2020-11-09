#version 330

#extension GL_GOOGLE_include_directive : enable

#include "shaders/common_sequences.inc.glsl"

#define M_PI 3.1415926535897932384626433
#define TWO_PI 6.2831853071795864769252867

uniform vec4 SampleRadius_MaxDistance_AOStrength_ZBias;
#define sampleRadius (SampleRadius_MaxDistance_AOStrength_ZBias.x)
#define maxDistance (SampleRadius_MaxDistance_AOStrength_ZBias.y)
#define aoStrength (SampleRadius_MaxDistance_AOStrength_ZBias.z)
#define zBias (SampleRadius_MaxDistance_AOStrength_ZBias.w)

uniform vec4 Near_Far_NoiseScale;
#define NEAR (Near_Far_NoiseScale.x)
#define FAR (Near_Far_NoiseScale.y)
#define noiseScale (Near_Far_NoiseScale.zw)

uniform vec2 pixelSize;

uniform mat4 trans_clip_of_camera_to_view_of_camera;
uniform mat4 trans_world_to_view_of_camera;

uniform sampler2D depthSampler;
uniform sampler2D normalSampler;
uniform sampler2D noiseSampler;

in vec2 l_texcoord;

out vec4 outputColor;

vec3 GetViewNormal(vec2 texcoord) {
  vec3 worldNormal = normalize(textureLod(normalSampler, texcoord, 0).xyz * 2 - 1);
  vec4 viewNormal = trans_world_to_view_of_camera * vec4(worldNormal, 0);
  return normalize(viewNormal.xyz);
}

vec3 GetViewPos(float z, vec2 texcoord) {
  vec4 viewPos = trans_clip_of_camera_to_view_of_camera * vec4((texcoord.xy * 2) - 1, z, 1.0);
  return viewPos.xyz / viewPos.w;
}

vec3 GetViewPos(vec2 texcoord) {
  float z = textureLod(depthSampler, texcoord, 0).x;
  return GetViewPos(z, texcoord);
}

float GetLinearZ(float z) {
  return 2.0 * NEAR * FAR / (FAR + NEAR - (z * 2.0 - 1) * (FAR - NEAR));
}

void main() {
  vec2 texcoord = l_texcoord;

  float pixelDepth = textureLod(depthSampler, texcoord, 0).x;
  float pixelDistance = GetLinearZ(pixelDepth);

  if (pixelDistance > 1000.0) {
    outputColor = vec4(1);
    return;
  }

  vec3 pixelViewNormal = GetViewNormal(texcoord);

  vec3 pixelViewPos = GetViewPos(pixelDepth, texcoord);

  float kernelScale = min(5.0, 10.0 / pixelDistance);

  vec2 noiseVec = textureLod(noiseSampler, texcoord * noiseScale, 0).xy * 2 - 1;

  float accum = 0.0;
  float accumCount = 0;
  vec2 offsetScale = pixelSize * sampleRadius * kernelScale * 0.4;

  for (int i = 0; i < 8; i++) {
    vec2 offset = halton_2D_8[i];
    offset = mix(offset, noiseVec, 0.3);

    vec2 offcoord = offset * offsetScale;

    // Get offset coordinates
    vec2 texcA = texcoord + offcoord;
    vec2 texcB = texcoord - offcoord;

    // Get view position at those offsets.
    vec3 offPosA = GetViewPos(texcA);
    offPosA.y += zBias;
    vec3 offPosB = GetViewPos(texcB);
    offPosB.y += zBias;

    // Get the vector s-p to that sample position
    vec3 sampleVecA = normalize(offPosA - pixelViewPos);
    vec3 sampleVecB = normalize(offPosB - pixelViewPos);

    // Get distances
    float distA = distance(offPosA, pixelViewPos) / maxDistance;
    float distB = distance(offPosB, pixelViewPos) / maxDistance;

    // Check if samples are valid
    float validA = step(distA - 1, 0.0);
    float validB = step(distB - 1, 0.0);

    float angleA = max(0, dot(sampleVecA, pixelViewNormal));
    float angleB = max(0, dot(sampleVecB, pixelViewNormal));

    if (validA != validB) {
      angleA = mix(-angleB, angleA, validA);
      angleB = mix(angleA, -angleB, validB);
      distA = mix(distB, distA, validA);
      distB = mix(distA, distB, validB);
    }

    // In case any sample is valid
    float anyValid = float((validA > 0.5) || (validB > 0.5));
    accum += ((angleA + angleB) * 0.25 * (2 - (distA + distB))) * anyValid;
    accumCount += max(0.5, anyValid);
  }

  accum /= max(1.0, accumCount);
  accum = 1 - accum;

  outputColor = vec4(accum, accum, accum, 1.0);

  outputColor.rgb = pow(clamp(outputColor.rgb, 0, 1), vec3(aoStrength));
  outputColor.rgb = pow(outputColor.rgb, vec3(3.0));
}
