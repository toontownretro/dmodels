/**
 * COG INVASION ONLINE
 * Copyright (c) CIO Team. All rights reserved.
 *
 * @file common.inc.glsl
 * @author Brian Lach
 * @date March 30, 2019
 *
 */

#ifndef COMMON_INC_GLSL
#define COMMON_INC_GLSL

#define SHADERQUALITY_LOW     0
#define SHADERQUALITY_MEDIUM  1
#define SHADERQUALITY_HIGH    2

#ifndef SHADER_QUALITY
#define SHADER_QUALITY SHADERQUALITY_HIGH
#endif

// ====================================================
// These functions exist to help perform conditionals
// without the need to use an if-statement and cause
// branching in the shader program.
// ====================================================

float max3(vec3 v) {
  return max(max(v.x, v.y), v.z);
}

float and(float a, float b) {
  return a * b;
}

float or(float a, float b) {
  return min(a + b, 1.0);
}

//float xor(float a, float b) {
//  return (a + b) % int(2);
//}

float not(float a) {
  return 1.0 - a;
}

float when_eq(float x, float y) {
  return 1.0 - abs(sign(x - y));
}

float when_neq(float x, float y) {
  return abs(sign(x - y));
}

float when_gt(float x, float y) {
  return max(sign(x - y), 0.0);
}

float when_lt(float x, float y) {
  return max(sign(y - x), 0.0);
}

float when_ge(float x, float y) {
  return 1.0 - when_lt(x, y);
}

float when_le(float x, float y) {
  return 1.0 - when_gt(x, y);
}

/**
 * Returns `x` when `y` is 1.
 * Returns 1 when `y` is 0.
 */
float mul_cmp(float x, float y) {
  return pow(x, y);
}

void GammaToLinear(inout vec4 vec)
{
    vec.xyz = pow(vec.xyz, vec3(2.2));
}

void LinearToGamma(inout vec4 vec)
{
    vec.xyz = pow(vec.xyz, vec3(1.0/2.2));
}

vec3 Project(mat4 mvp, vec3 p) {
    vec4 proj = mvp * vec4(p, 1);
    return (proj.xyz / proj.w) * vec3(0.5) + vec3(0.5);
}

// from http://www.java-gaming.org/index.php?topic=35123.0
vec4 cubic(float v){
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * (1.0/6.0);
}

vec4 textureArrayBicubic(sampler2DArray sampler, vec3 texCoords) {

   vec2 texSize = textureSize(sampler, 0).xy;
   vec2 invTexSize = 1.0 / texSize;

   texCoords.xy = texCoords.xy * texSize - 0.5;


    vec2 fxy = fract(texCoords.xy);
    texCoords.xy -= fxy;

    vec4 xcubic = cubic(fxy.x);
    vec4 ycubic = cubic(fxy.y);

    vec4 c = texCoords.xxyy + vec2 (-0.5, +1.5).xyxy;

    vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    vec4 offset = c + vec4 (xcubic.yw, ycubic.yw) / s;

    offset *= invTexSize.xxyy;

    vec4 sample0 = texture(sampler, vec3(offset.xz, texCoords.z));
    vec4 sample1 = texture(sampler, vec3(offset.yz, texCoords.z));
    vec4 sample2 = texture(sampler, vec3(offset.xw, texCoords.z));
    vec4 sample3 = texture(sampler, vec3(offset.yw, texCoords.z));

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix(
       mix(sample3, sample2, sx), mix(sample1, sample0, sx)
    , sy);
}

vec3 WorldToTangent(vec3 worldVector, vec3 worldNormal, vec3 worldTangent, vec3 worldBinormal) {
    vec3 tangentVector = vec3(0);
    tangentVector.x = dot(worldVector, worldTangent);
    tangentVector.y = dot(worldVector, worldBinormal);
    tangentVector.z = dot(worldVector, worldNormal);
    return tangentVector;
}

vec3 WorldToTangentNormalized(vec3 worldVector, vec3 worldNormal, vec3 worldTangent, vec3 worldBinormal) {
    return normalize(WorldToTangent(worldVector, worldNormal, worldTangent, worldBinormal));
}

vec3 TangentToWorld(vec3 tangentVector, vec3 worldNormal, vec3 worldTangent, vec3 worldBinormal) {
  vec3 worldVector = vec3(0);
  worldVector.xyz = tangentVector.x * worldTangent.xyz;
  worldVector.xyz += tangentVector.y * worldBinormal.xyz;
  worldVector.xyz += tangentVector.z * worldNormal.xyz;
  return worldVector;
}

vec3 TangentToWorldNormalized(vec3 tangentVector, vec3 worldNormal, vec3 worldTangent, vec3 worldBinormal) {
  return normalize(TangentToWorld(tangentVector, worldNormal, worldTangent, worldBinormal));
}

#endif // COMMON_INC_GLSL
