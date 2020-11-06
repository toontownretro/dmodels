#version 330

#define M_PI 3.1415926535897932384626433
#define TWO_PI 6.2831853071795864769252867

uniform vec4 SampleDirections_SampleSteps_NoiseScale;
#define numSampleDirections (SampleDirections_SampleSteps_NoiseScale.x)
#define numSampleSteps (SampleDirections_SampleSteps_NoiseScale.y)
#define noiseScale (SampleDirections_SampleSteps_NoiseScale.z)

uniform vec4 FOV_SampleRadius_AngleBias_Intensity;
#define fov (FOV_SampleRadius_AngleBias_Intensity.x)
#define sampleRadius (FOV_SampleRadius_AngleBias_Intensity.y)
#define angleBias (FOV_SampleRadius_AngleBias_Intensity.z)
#define intensity (FOV_SampleRadius_AngleBias_Intensity.w)

uniform sampler2D depthSampler;
uniform sampler2D normalSampler;
uniform sampler2D noiseSampler;

// Inverse projection matrix of scene camera
uniform mat4 trans_clip_of_camera_to_view_of_camera;
// Move from world-space to scene camera view space
uniform mat4 trans_world_to_view_of_camera;
// Move from scene camera clip space to world space.
uniform mat4 trans_clip_of_camera_to_world;

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

  // Radius of influence in screen space.
  float screenRadius = 0.0;
  // Radius of influence in world space.
  float worldRadius = 0.0;

  screenRadius = sampleRadius;
  vec4 temp0 = trans_clip_of_camera_to_world * vec4(0.0, 1, 0, 1.0);
  vec3 out0 = temp0.xyz;
  vec4 temp1 = trans_clip_of_camera_to_world * vec4(screenRadius, 1, 0, 1.0);
  vec3 out1 = temp1.xyz;

  // Clamp world space radius based on screen space radius projection to avoid
  // artifacts.
  //worldRadius = min(tan(screenRadius * fov / 2.0) * viewOrigin.y / 2.0, length(out1 - out0));
  //worldRadius = 20;
  worldRadius = length(out1 - out0);

  float theta = TWO_PI / numSampleDirections;
  float cosTheta = cos(theta);
  float sinTheta = sin(theta);

  // Matrix to create the sample directions.
  mat2 deltaRotationMatrix = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

  // Step vector in view space.
  vec2 deltaUV = vec2(1.0, 0.0) * (screenRadius / (numSampleDirections * numSampleSteps + 1.0));

  vec3 sampleNoise = textureLod(noiseSampler, l_texcoord, 0).xyz * noiseScale;
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

      // Angle between fragment tangent and the sample
      float gamma = (M_PI / 2.0) - acos(dot(viewNormal, normalize(viewSampleDir)));

      if (gamma > oldAngle) {
        float value = sin(gamma) - sin(oldAngle);

        float atten = clamp(1.0 - pow(length(viewSampleDir) / worldRadius, 2.0), 0.0, 1.0);
        occlusion += atten * value;

        oldAngle = gamma;
      }
    }
  }

  occlusion = 1.0 - occlusion / numSampleDirections;
  occlusion = clamp(pow(occlusion, 1.0 + intensity), 0.0, 1.0);

  outputColor = vec4(occlusion, occlusion, occlusion, 1.0);
}
