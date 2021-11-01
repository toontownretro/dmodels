#version 430

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

uniform samplerCube inputTexture;
uniform writeonly imageCube outputTexture;

uniform ivec3 mipLevel_mipSize_numMips;
#define mipLevel (mipLevel_mipSize_numMips.x)
#define mipSize (mipLevel_mipSize_numMips.y)
#define numMips (mipLevel_mipSize_numMips.z)

const float PI = 3.14159265359;

float RadicalInverse_VdC(uint bits)
{
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}
// ----------------------------------------------------------------------------
vec2 Hammersley(uint i, uint N) {
  return vec2(float(i)/float(N), RadicalInverse_VdC(i));
}

vec3 ImportanceSampleGGX(vec2 Xi, vec3 N, float roughness) {
  float a = roughness*roughness;

  float phi = 2.0 * PI * Xi.x;
  float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));
  float sinTheta = sqrt(1.0 - cosTheta*cosTheta);

  // from spherical coordinates to cartesian coordinates
  vec3 H;
  H.x = cos(phi) * sinTheta;
  H.y = sin(phi) * sinTheta;
  H.z = cosTheta;

  // from tangent-space vector to world-space sample vector
  vec3 up        = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
  vec3 tangent   = normalize(cross(up, N));
  vec3 bitangent = cross(N, tangent);

  vec3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
  return normalize(sampleVec);
}

vec3 SampleCubeMapFilteredLod(samplerCube cubeSampler, vec3 worldEyeToVert, float roughness) {
  vec3 N = normalize(worldEyeToVert);
  vec3 R = N;
  vec3 V = R;

  const uint SAMPLE_COUNT = 4096u;
  float totalWeight = 0.0;
  vec3 prefilteredColor = vec3(0.0);
  for (uint i = 0u; i < SAMPLE_COUNT; i++) {
    vec2 Xi = Hammersley(i, SAMPLE_COUNT);
    vec3 H = ImportanceSampleGGX(Xi, N, roughness);
    float HdotV = dot(H, V);
    vec3 L = normalize(2.0 * HdotV * H - V);

    float NdotL = max(dot(N, L), 0.0);
    if (NdotL > 0.0) {
      prefilteredColor += textureLod(cubeSampler, L, 0).rgb * NdotL;
      totalWeight += NdotL;
    }
  }

  prefilteredColor = prefilteredColor / totalWeight;

  return prefilteredColor;
}

vec3 cubeCoordToWorld(ivec3 cubeCoord, float mSize) {
  vec2 texcoord = vec2(cubeCoord.xy) / mSize;
  texcoord = texcoord * 2.0 - 1.0;
  switch (cubeCoord.z) {
  case 0:
    return vec3(1.0, -texcoord.y, -texcoord.x);
  case 1:
    return vec3(-1.0, -texcoord.y, texcoord.x);
  case 2:
    return vec3(texcoord.x, 1.0, texcoord.y);
  case 3:
    return vec3(texcoord.x, -1.0, -texcoord.y);
  case 4:
    return vec3(texcoord.x, -texcoord.y, 1.0);
  case 5:
    return vec3(-texcoord.x, -texcoord.y, -1.0);
  default:
    return vec3(0.0);
  }
}

void main() {
  ivec3 cubeCoord = ivec3(gl_GlobalInvocationID);
  if (cubeCoord.x >= mipSize || cubeCoord.y >= mipSize || cubeCoord.z >= 6) {
    return;
  }
  vec3 worldPos = cubeCoordToWorld(cubeCoord, float(mipSize));
  vec3 color = SampleCubeMapFilteredLod(inputTexture, worldPos, mipLevel / float(numMips - 1));
  imageStore(outputTexture, cubeCoord, vec4(color, 1.0));
}
