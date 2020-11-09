// This is a HBAO-Shader for OpenGL, based upon nvidias directX implementation
// supplied in their SampleSDK available from nvidia.com
// The slides describing the implementation is available at
// http://www.nvidia.co.uk/object/siggraph-2008-HBAO.html

#version 330

const float PI = 3.14159265;

uniform sampler2D depthSampler;
uniform sampler2D noiseSampler;

uniform vec4 FocalLen_LinMAD;
#define FocalLen (FocalLen_LinMAD.xy)
#define LinMAD (FocalLen_LinMAD.zw)

uniform vec4 UVToViewA_B;
#define UVToViewA (UVToViewA_B.xy)
#define UVToViewB (UVToViewA_B.zw)

uniform vec4 AORes_Inv;
#define AORes (AORes_Inv.xy)
#define InvAORes (AORes_Inv.zw)

uniform vec4 NoiseScale_MaxRadiusPixels_ZBias;
#define NoiseScale (NoiseScale_MaxRadiusPixels_ZBias.xy)
#define MaxRadiusPixels (NoiseScale_MaxRadiusPixels_ZBias.z)
#define ZBias (NoiseScale_MaxRadiusPixels_ZBias.w)

const float tanBias = tan(30.0 * PI / 180.0);

uniform vec4 AOStrength_R_R2_NegInvR2;
#define AOStrength (AOStrength_R_R2_NegInvR2.x)
#define R (AOStrength_R_R2_NegInvR2.y)
#define R2 (AOStrength_R_R2_NegInvR2.z)
#define NegInvR2 (AOStrength_R_R2_NegInvR2.w)

uniform ivec2 NumDirections_Samples;
#define NumDirections (NumDirections_Samples.x)
#define NumSamples (NumDirections_Samples.y)

in vec2 l_texcoord;

out vec4 out_frag0;

float ViewSpaceZFromDepth(float d) {
  // [0,1] -> [-1,1] clip space
  d = d * 2.0 - 1.0;

  // Get view space Z
  return -1.0 / (LinMAD.x * d + LinMAD.y);
}

vec3 UVToViewSpace(vec2 uv, float z) {
  uv = UVToViewA * uv + UVToViewB;
  return vec3(uv * z, z);
}

vec3 GetViewPos(vec2 uv) {
  float z = ViewSpaceZFromDepth(texture(depthSampler, uv).r);
  //float z = texture(depthSampler, uv).r;
  return UVToViewSpace(uv, z);
}

vec3 GetViewPosPoint(ivec2 uv) {
  ivec2 coord = ivec2(gl_FragCoord.xy) + uv;
  float z = texelFetch(depthSampler, coord, 0).r;
  return UVToViewSpace(uv, z);
}

float TanToSin(float x) {
  return x * inversesqrt(x*x + 1.0);
}

float InvLength(vec2 V) {
  return inversesqrt(dot(V,V));
}

float Tangent(vec3 V) {
  return V.z * InvLength(V.xy);
}

float BiasedTangent(vec3 V) {
  return V.z * InvLength(V.xy) + tanBias;
}

float Tangent(vec3 P, vec3 S) {
  return -(P.z - S.z) * InvLength(S.xy - P.xy);
}

float Length2(vec3 V) {
  return dot(V,V);
}

vec3 MinDiff(vec3 P, vec3 Pr, vec3 Pl) {
  vec3 V1 = Pr - P;
  vec3 V2 = P - Pl;
  return (Length2(V1) < Length2(V2)) ? V1 : V2;
}

vec2 SnapUVOffset(vec2 uv) {
  return round(uv * AORes) * InvAORes;
}

float Falloff(float d2) {
  return d2 * NegInvR2 + 1.0f;
}

float HorizonOcclusion(vec2 deltaUV, vec3 P, vec3 dPdu, vec3 dPdv,
                       float randstep, float numSamples) {
  float ao = 0;

  // Offset the first coord with some noise
  vec2 uv = l_texcoord + SnapUVOffset(randstep * deltaUV);
  deltaUV = SnapUVOffset(deltaUV);

  // Calculate the tangent vector
  vec3 T = deltaUV.x * dPdu + deltaUV.y * dPdv;

  // Get the angle of the tangent vector from the viewspace axis
  float tanH = BiasedTangent(T);
  float sinH = TanToSin(tanH);

  float tanS;
  float d2;
  vec3 S;

  // Sample to find the maximum angle
  for (float s = 1; s <= numSamples; ++s) {
    uv += deltaUV;
    S = GetViewPos(uv);
    tanS = Tangent(P, S);
    S.y += ZBias;
    d2 = Length2(S - P);

    // Is the sample within the radius and the angle greater?
    if (d2 < R2 && tanS > tanH) {
      float sinS = TanToSin(tanS);
      // Apply falloff based on the distance
      ao += Falloff(d2) * (sinS - sinH);

      tanH = tanS;
      sinH = sinS;
    }
  }

  return ao;
}

vec2 RotateDirections(vec2 Dir, vec2 CosSin) {
  return vec2(Dir.x*CosSin.x - Dir.y*CosSin.y,
              Dir.x*CosSin.y + Dir.y*CosSin.x);
}

void ComputeSteps(inout vec2 stepSizeUv, inout float numSteps,
                  float rayRadiusPix, float rand) {
  // Avoid oversampling if numSteps is greater than the kernel radius in pixels
  numSteps = min(NumSamples, rayRadiusPix);

  // Divide by Ns+1 so that the farthest samples are not fully attenuated
  float stepSizePix = rayRadiusPix / (numSteps + 1);

  // Clamp numSteps if it is greater than the max kernel footprint
  float maxNumSteps = MaxRadiusPixels / stepSizePix;
  if (maxNumSteps < numSteps) {
    // Use dithering to avoid AO discontinuities
    numSteps = floor(maxNumSteps + rand);
    numSteps = max(numSteps, 1);
    stepSizePix = MaxRadiusPixels / numSteps;
  }

  // Step size in uv space
  stepSizeUv = stepSizePix * InvAORes;
}

void main() {
  float numDirections = NumDirections;

  vec3 P, Pr, Pl, Pt, Pb;
  P = GetViewPos(l_texcoord);

  // Sample neighboring pixels
  Pr = GetViewPos(l_texcoord + vec2( InvAORes.x, 0));
  Pl = GetViewPos(l_texcoord + vec2(-InvAORes.x, 0));
  Pt = GetViewPos(l_texcoord + vec2( 0, InvAORes.y));
  Pb = GetViewPos(l_texcoord + vec2( 0,-InvAORes.y));

  // Calculate tangent basis vectors using the minimu difference
  vec3 dPdu = MinDiff(P, Pr, Pl);
  vec3 dPdv = MinDiff(P, Pt, Pb) * (AORes.y * InvAORes.x);

  // Get the random samples from the noise texture
  vec3 random = texture(noiseSampler, l_texcoord.xy * NoiseScale).rgb;

  // Calculate the projected size of the hemisphere
  vec2 rayRadiusUV = 0.5 * R * FocalLen / -P.z;
  float rayRadiusPix = rayRadiusUV.x * AORes.x;

  float ao = 1.0;

  // Make sure the radius of the evaluated hemisphere is more than a pixel
  if (rayRadiusPix > 1.0) {
    ao = 0.0;
    float numSteps;
    vec2 stepSizeUV;

    // Compute the number of steps
    ComputeSteps(stepSizeUV, numSteps, rayRadiusPix, random.z);

    float alpha = 2.0 * PI / numDirections;

    // Calculate the horizon occlusion of each direction
    for (float d = 0; d < numDirections; ++d) {
      float theta = alpha * d;

      // Apply noise to the direction
      vec2 dir = RotateDirections(vec2(cos(theta), sin(theta)), random.xy);
      vec2 deltaUV = dir * stepSizeUV;

      // Sample the pixels along the direction
      ao += HorizonOcclusion(deltaUV, P, dPdu, dPdv, random.z, numSteps);
    }

    // Average the results and produce the final AO
    ao = 1.0 - ao / numDirections * AOStrength;
  }

  out_frag0 = vec4(ao, 30.0 * P.z, 0, 0);
}
