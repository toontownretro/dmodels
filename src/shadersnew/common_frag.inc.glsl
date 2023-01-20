
#ifndef COMMON_FRAG_INC_GLSL
#define COMMON_FRAG_INC_GLSL

#include "shadersnew/common.inc.glsl"

#define M_none 0
#define M_never 1
#define M_less 2
#define M_equal 3
#define M_less_equal 4
#define M_greater 5
#define M_not_equal 6
#define M_greater_equal 7
#define M_always 8
/**
 * Returns false if the alpha value fails the comparision test,
 * or true if it passes.
 */
bool
do_alpha_test(in float alpha, int mode, float ref) {
  switch (mode) {
  case M_never:
    return false;
  case M_less: // Less.
    return alpha < ref;
  case M_equal: // Equal
    return alpha == ref;
  case M_less_equal: // Less equal.
    return alpha <= ref;
  case M_greater: // Greater.
    return alpha > ref;
  case M_not_equal: // Not equal.
    return alpha != ref;
  case M_greater_equal: // Greater equal.
    return alpha >= ref;
  case M_always:
  case M_none:
  default:
    return true;
  }
}

#define FM_linear 0
#define FM_exponential 1
#define FM_exponential_squared 2
/**
 * Performs fogging on the input color.  Returns the new color with fog
 * applied.
 */
vec3
do_fog(in vec3 input_color, in vec3 eye_position, vec3 fog_color,
       in float exp_density, in float linear_end, in float linear_scale,
       in int fog_mode) {

  float dist = length(eye_position);

  switch (fog_mode) {
  case FM_linear:
    {
      // Squaring the factor is closer to fixed-function fog.
      float fog_factor = clamp(1.0 - ((linear_end - dist) * linear_scale), 0.0, 1.0);
      return mix(input_color, fog_color, fog_factor * fog_factor);
    }

  case FM_exponential:
    return mix(fog_color, input_color, clamp(exp2(exp_density * dist * -1.442695), 0, 1));

  case FM_exponential_squared:
    return mix(fog_color, input_color, clamp(exp2(exp_density * exp_density * dist * dist * -1.442695), 0.0, 1.0));

  default:
    return input_color;
  }
}

#define COSINE_A0 (1.0)
#define COSINE_A1 (2.0 / 3.0)
#define COSINE_A2 (1.0 / 4.0)

/**
 *
 */
vec3
sample_l2_ambient_probe(in vec3 probe[9], in vec3 normal) {
  vec3 color;
  color = probe[0] * 0.282095 * COSINE_A0;
  color += probe[1] * -0.488603 * normal.y * COSINE_A1;
  color += probe[2] * 0.488603 * normal.z * COSINE_A1;
  color += probe[3] * -0.488603 * normal.x * COSINE_A1;
  color += probe[4] * 1.092548 * normal.x * normal.y * COSINE_A2;
  color += probe[5] * -1.092548 * normal.y * normal.z * COSINE_A2;
  color += probe[6] * 0.315392 * (3.0 * normal.z * normal.z - 1.0) * COSINE_A2;
  color += probe[7] * -1.092548 * normal.x * normal.z * COSINE_A2;
  color += probe[8] * 0.546274 * (normal.x * normal.x - normal.y * normal.y) * COSINE_A2;
  return color;
}

/**
 *
 */
vec3
sample_l1_lightmap_bicubic(in sampler2D lightmap_l0, in sampler2D lightmap_l1x, in sampler2D lightmap_l1y,
                           in sampler2D lightmap_l1z, in vec3 normal, in vec2 texcoord) {
  vec3 L0 = textureBicubic(lightmap_l0, texcoord).rgb;
  vec3 L0factor = (L0 / 0.282095) * 0.488603;
  vec3 L1y = textureBicubic(lightmap_l1y, texcoord).rgb * 2 - 1;
  L1y *= L0factor;
  vec3 L1z = textureBicubic(lightmap_l1z, texcoord).rgb * 2 - 1;
  L1z *= L0factor;
  vec3 L1x = textureBicubic(lightmap_l1x, texcoord).rgb * 2 - 1;
  L1x *= L0factor;
  vec3 color = L0 * 0.282095 * COSINE_A0;
  color += L1y * -0.488603 * normal.y * COSINE_A1;
  color += L1z * 0.488603 * normal.z * COSINE_A1;
  color += L1x * -0.488603 * normal.x * COSINE_A1;
  return color;
}

#endif // COMMON_FRAG_INC_GLSL
