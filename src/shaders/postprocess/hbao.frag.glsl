#version 330

#extension GL_GOOGLE_include_directive : enable

#include "shaders/common_sequences.inc.glsl"

#define M_PI 3.1415926535897932384626433
#define TWO_PI 6.2831853071795864769252867

uniform vec4 SampleRadius_TangentBias_MaxSampleDistance_AOStrength;
uniform ivec2 NumAngles_NumRaySteps;

#define sampleRadius (SampleRadius_TangentBias_MaxSampleDistance_AOStrength.x)
#define tangentBias (SampleRadius_TangentBias_MaxSampleDistance_AOStrength.y)
#define maxSampleDistance (SampleRadius_TangentBias_MaxSampleDistance_AOStrength.z)
#define aoStrength (SampleRadius_TangentBias_MaxSampleDistance_AOStrength.w)

#define numAngles (NumAngles_NumRaySteps.x)
#define numRaySteps (NumAngles_NumRaySteps.y)

//uniform vec4 SampleRadius_MaxDistance_AOStrength_ClipLength;
//#define sampleRadius (SampleRadius_MaxDistance_AOStrength_ClipLength.x)
//#define maxDistance (SampleRadius_MaxDistance_AOStrength_ClipLength.y)
//#define aoStrength (SampleRadius_MaxDistance_AOStrength_ClipLength.z)
//#define clipLength (SampleRadius_MaxDistance_AOStrength_ClipLength.w)
uniform vec2 ZBias_ClipLength;
#define zBias (ZBias_ClipLength.x)
#define clipLength (ZBias_ClipLength.y)

uniform ivec2 WindowSize;

uniform vec2 NearFar;
#define NEAR (NearFar.x)
#define FAR (NearFar.y)

uniform sampler2D depthSampler;
uniform sampler2D normalSampler;

uniform int osg_FrameNumber;

// Inverse projection matrix of scene camera
uniform mat4 trans_clip_of_camera_to_view_of_camera;
// Move from world-space to scene camera view space
uniform mat4 trans_world_to_view_of_camera;

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

vec3 RandRGB(vec2 co)
{
    return abs(fract(sin(dot(co.xy, vec2(34.4835, 89.6372))) *
        vec3(29156.4765, 38273.56393, 47843.75468))) * 2 - 1;
}

void main() {
  vec2 screenSize = vec2(WindowSize.x, WindowSize.y);
  vec2 pixelSize = vec2(1.0) / screenSize;

  ivec2 coord = ivec2(gl_FragCoord.xy) * 2;
  //vec2 texcoord = (coord + 0.5) / screenSize;
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

  vec3 noiseVec = RandRGB(coord % 8 + 0.05 * (osg_FrameNumber % int(clipLength)));

#if 0
  float accum = 0.0;
  float accumCount = 0;
  vec2 offsetScale = pixelSize * sampleRadius * kernelScale * 0.4;

  for (int i = 0; i < 64; i++) {
    vec2 offset = halton_2D_64[i];
    offset = mix(offset, noiseVec.xy, 0.3);

    vec2 offcoord = offset * offsetScale;

    // Get offset coordinates
    vec2 texcA = texcoord + offcoord;
    vec2 texcB = texcoord - offcoord;

    // Get view position at those offsets.  Offset the positions along the
    // normal to prevent acne.
    vec3 offPosA = GetViewPos(texcA);
    offPosA.y += zBias;
    //vec3 offNormA = GetViewNormal(texcA);
    //offPosA -= offNormA * zBias;
    vec3 offPosB = GetViewPos(texcB);
    offPosB.y += zBias;
    //vec3 offNormB = GetViewNormal(texcB);
    //offPosB -= offNormB * zBias;

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
    if (validA > 0.5 || validB > 0.5) {
      accum += (angleA + angleB) * 0.25 * (2 - (distA + distB));
      accumCount += 1.0;
    } else {
      accumCount += 0.5;
    }
  }

  accum /= max(1.0, accumCount);
  accum = 1 - accum;

#endif

#if 1
  float accum = 0.0;

  for (int i = 0; i < numAngles; i++) {
    float angle = (i /*+ 2 * noiseVec.x*/) / float(numAngles) * TWO_PI;

    vec2 sampleDir = vec2(cos(angle), sin(angle));

    // Find the tangent angle
    float tangentAngle = acos(dot(vec3(sampleDir, 0), pixelViewNormal)) - 0.5 * M_PI
      + tangentBias;

    // Assume the horizon angle is the same as the tangent angle at the
    // beginning of the ray.
    float horizonAngle = tangentAngle;

    vec3 lastDiff = vec3(0);

    // Ray-march in the sample direction.
    for (int k = 0; k < numRaySteps; k++) {
      // Get the new texture coordinate.
      vec2 texc = texcoord + sampleDir * (k + 2.0 /*+ 2 * noiseVec.y*/) /
        numRaySteps * pixelSize * sampleRadius * kernelScale * 0.3;

      // Fetch view pos at that position and compare it.
      vec3 viewPos = GetViewPos(texc);
      viewPos.y += zBias;
      vec3 diff = viewPos - pixelViewPos;

      if (length(diff) < maxSampleDistance) {

        // Compute actual angle
        float sampleAngle = atan(diff.z / length(diff.xy));

        // Correct horizon angle
        horizonAngle = max(horizonAngle, sampleAngle);
        lastDiff = diff;
      }
    }

    // Now that we know the average horizon angle, add it to the result.  For
    // that we simply take the angle difference.
    float occlusion = clamp(sin(horizonAngle) - sin(tangentAngle), 0, 1);
    occlusion *= 1.0 / (1 + length(lastDiff));
    accum += occlusion;
  }

  // Normalize angles
  accum /= numAngles;
  accum = 1 - accum;

#endif

  outputColor = vec4(accum, accum, accum, 1.0);

  outputColor.rgb = pow(clamp(outputColor.rgb, 0, 1), vec3(aoStrength));
  outputColor.rgb = pow(outputColor.rgb, vec3(3.0));
}
