#version 330

#define M_PI 3.1415926535897932384626433
#define TWO_PI 6.2831853071795864769252867

uniform vec4 SampleDirections_SampleSteps_NoiseScale;
#define numSampleDirections (SampleDirections_SampleSteps_NoiseScale.x)
#define numSampleSteps (SampleDirections_SampleSteps_NoiseScale.y)
#define noiseScale (SampleDirections_SampleSteps_NoiseScale.z)

uniform vec4 FallOff_SampleRadius_AngleBias_Intensity;
#define fallOff (FallOff_SampleRadius_AngleBias_Intensity.x)
#define sampleRadius (FallOff_SampleRadius_AngleBias_Intensity.y)
#define angleBias (FallOff_SampleRadius_AngleBias_Intensity.z)
#define intensity (FallOff_SampleRadius_AngleBias_Intensity.w)

uniform vec2 MaxSampleDistance;
#define maxSampleDistance (MaxSampleDistance.x)

uniform sampler2D depthSampler;
uniform sampler2D normalSampler;
uniform sampler2D noiseSampler;

// Inverse projection matrix of scene camera
uniform mat4 trans_clip_of_camera_to_view_of_camera;
// Move from world-space to scene camera view space
uniform mat4 trans_world_to_view_of_camera;
// Move from scene camera view space to scene-camera clip space.
uniform mat4 trans_view_of_camera_to_clip_of_camera;

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

void main() {
  vec3 viewOrigin = GetViewPos(l_texcoord);
  vec3 viewNormal = GetViewNormal(l_texcoord);

  float viewRadius = sampleRadius;

  // Convert view-space radius parameter to a UV-space radius.
  vec4 screenRadiusVec = trans_view_of_camera_to_clip_of_camera *
    vec4(viewRadius, viewOrigin.y, viewRadius, 1.0);
  // Perspective divide to have a lower UV-space radius the further away the
  // pixel is.
  float screenRadius = screenRadiusVec.x / screenRadiusVec.w;

  //outputColor =  vec4(screenRadius, 1, 1);
  //return;

  float theta = TWO_PI / numSampleDirections;
  float cosTheta = cos(theta);
  float sinTheta = sin(theta);

  // Matrix to create the sample directions.
  mat2 deltaRotationMatrix = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

  // Step vector in view space.
  vec2 deltaUV = vec2(1.0, 0.0) * (screenRadius / (numSampleDirections * numSampleSteps + 1.0));

  vec3 sampleNoise = textureLod(noiseSampler, l_texcoord * noiseScale, 0).xyz;
  sampleNoise.xy = sampleNoise.xy * 2.0 - vec2(1.0);
  mat2 rotateMat = mat2(sampleNoise.x, -sampleNoise.y, sampleNoise.y, sampleNoise.x);

  // Apply a random rotation to the base step vector.
  deltaUV = rotateMat * deltaUV;

  float jitter = sampleNoise.z;
  float occlusion = 0.0;

  for (int i = 0; i < int(numSampleDirections); i++) {
    // Incrementally rotate sample direction.
    deltaUV = deltaRotationMatrix * deltaUV;

    vec2 sampleDirUV = deltaUV;
    float oldAngle = angleBias;

    for (int j = 0; j < numSampleSteps; j++) {
      vec2 sampleUV = l_texcoord + (jitter + float(j)) * sampleDirUV;
      vec3 viewSample = GetViewPos(sampleUV);
      vec3 viewSampleDir = (viewSample - viewOrigin);
      float sampleDistance = length(viewSampleDir);

      // Angle between fragment tangent and the sample
      float gamma = (M_PI / 2.0) - acos(dot(viewNormal, viewSampleDir / sampleDistance));

      if (gamma > oldAngle && sampleDistance <= maxSampleDistance) {
        float value = sin(gamma) - sin(oldAngle);

        // Distance falloff
        float atten = clamp(1.0 / (fallOff * sampleDistance * sampleDistance), 0, 1);
        //atten = 1.0 - atten;
        occlusion += atten * value;

        oldAngle = gamma;
      }
    }
  }

  occlusion = 1.0 - occlusion / numSampleDirections;
  occlusion = clamp(pow(occlusion, 1.0 + intensity), 0.0, 1.0);

  outputColor = vec4(occlusion, occlusion, occlusion, 1.0);
}
