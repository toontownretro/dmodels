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

#endif // COMMON_INC_GLSL
