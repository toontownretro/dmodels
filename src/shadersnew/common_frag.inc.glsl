
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
#define DIR_FACTOR (0.32573)

/**
 *
 */
vec3
sample_l2_ambient_probe(in vec3 probe[9], in vec3 normal) {
  vec3 color;
  color = probe[0] * 0.282095 * COSINE_A0;
  color += probe[1] * 0.488603 * normal.y * COSINE_A1;
  color += probe[2] * 0.488603 * normal.z * COSINE_A1;
  color += probe[3] * 0.488603 * normal.x * COSINE_A1;
  color += probe[4] * 1.092548 * normal.x * normal.y * COSINE_A2;
  color += probe[5] * 1.092548 * normal.y * normal.z * COSINE_A2;
  color += probe[6] * 0.315392 * (3.0 * normal.z * normal.z - 1.0) * COSINE_A2;
  color += probe[7] * 1.092548 * normal.x * normal.z * COSINE_A2;
  color += probe[8] * 0.546274 * (normal.x * normal.x - normal.y * normal.y) * COSINE_A2;
  /*const float c1 = 0.429043;
  const float c2 = 0.511664;
  const float c3 = 0.743125;
  const float c4 = 0.886227;
  const float c5 = 0.247708;
  color = (c1 * probe[8] * (normal.x * normal.x - normal.y * normal.y) +
           c3 * probe[6] * normal.z * normal.z +
           c4 * probe[0] -
           c5 * probe[6] +
           2.0 * c1 * probe[4] * normal.x * normal.y +
           2.0 * c1 * probe[7] * normal.x * normal.z +
           2.0 * c1 * probe[5] * normal.y * normal.z +
           2.0 * c2 * probe[3] * normal.x +
           2.0 * c2 * probe[1] * normal.y +
           2.0 * c2 * probe[2] * normal.z);*/
  return color;
}

float
sample_l1_irradiance_geomerics(vec3 dir, vec4 sh) {
  float R0 = sh[0];

  vec3 R1 = 0.5 * vec3(-sh[3], -sh[1], sh[2]);
  float len_r1 = length(R1);

  float q = 0.5 * (1.0 + dot(R1 / len_r1, dir));

  float p = 1.0 + 2.0 * len_r1 / R0;
  float a = (1.0 - len_r1 / R0) / (1.0 + len_r1 / R0);

  return R0 * (a + (1.0 - a) * (p + 1.0) * pow(abs(q), p));
}

/**
 * Samples the SH, doesn't evaluate for a direction.
 */
void
get_l1_lightmap_sample(in sampler2D lightmap_l0, in sampler2D lightmap_l1x, in sampler2D lightmap_l1y,
                       in sampler2D lightmap_l1z, in vec2 texcoord, out vec3 sh[4])
{
  vec3 L0 = textureBicubic(lightmap_l0, texcoord).rgb;
  vec3 L0factor = (L0 / 0.282095) * 0.488603;
  vec3 L1y = textureBicubic(lightmap_l1y, texcoord).rgb * 2 - 1;
  L1y *= L0factor;
  vec3 L1z = textureBicubic(lightmap_l1z, texcoord).rgb * 2 - 1;
  L1z *= L0factor;
  vec3 L1x = textureBicubic(lightmap_l1x, texcoord).rgb * 2 - 1;
  L1x *= L0factor;

  sh[0] = L0 * 0.282095;
  sh[1] = L1y * -DIR_FACTOR;
  sh[2] = L1z * DIR_FACTOR;
  sh[3] = L1x * -DIR_FACTOR;
}

vec3
eval_sh_l1(in vec3 sh[4], in vec3 normal) {
  return sh[0] + sh[1] * normal.y + sh[2] * normal.z + sh[3] * normal.x;
}


// texture combining modes for combining base and detail/basetexture2
#define TCOMBINE_RGB_EQUALS_BASE_x_DETAILx2 0				// original mode
#define TCOMBINE_RGB_ADDITIVE 1								// base.rgb+detail.rgb*fblend
#define TCOMBINE_DETAIL_OVER_BASE 2
#define TCOMBINE_FADE 3										// straight fade between base and detail.
#define TCOMBINE_BASE_OVER_DETAIL 4                         // use base alpha for blend over detail
#define TCOMBINE_RGB_ADDITIVE_SELFILLUM 5                   // add detail color post lighting
#define TCOMBINE_RGB_ADDITIVE_SELFILLUM_THRESHOLD_FADE 6
#define TCOMBINE_MOD2X_SELECT_TWO_PATTERNS 7				// use alpha channel of base to select between mod2x channels in r+a of detail
#define TCOMBINE_MULTIPLY 8
#define TCOMBINE_MASK_BASE_BY_DETAIL_ALPHA 9                // use alpha channel of detail to mask base
#define TCOMBINE_SSBUMP_BUMP 10								// use detail to modulate lighting as an ssbump
#define TCOMBINE_SSBUMP_NOBUMP 11					// detail is an ssbump but use it as an albedo. shader does the magic here - no user needs to specify mode 11
/**
 *
 */
vec4
texture_combine(vec4 a, vec4 b, int mode, float factor) {
  switch (mode) {

  case TCOMBINE_RGB_EQUALS_BASE_x_DETAILx2:
    a.rgb *= mix(vec3(1), 2.0 * b.rgb, factor);
    break;

  case TCOMBINE_MOD2X_SELECT_TWO_PATTERNS:
    {
      vec3 dc = vec3(mix(b.r, b.a, a.a));
      a.rgb *= mix(vec3(1), 2.0 * dc, factor);
    }
    break;

  case TCOMBINE_RGB_ADDITIVE:
    a.rgb += factor * b.rgb;
    break;

  case TCOMBINE_DETAIL_OVER_BASE:
    {
      float blend = factor * b.a;
      a.rgb = mix(a.rgb, b.rgb, blend);
    }
    break;

  case TCOMBINE_FADE:
    a = mix(a, b, factor);
    break;

  case TCOMBINE_BASE_OVER_DETAIL:
    {
      float blend = factor * (1 - a.a);
      a.rgb = mix(a.rgb, b.rgb, blend);
      a.a = b.a;
    }
    break;

  case TCOMBINE_MULTIPLY:
    a = mix(a, a * b, factor);
    break;

  case TCOMBINE_MASK_BASE_BY_DETAIL_ALPHA:
    a.a = mix(a.a, a.a * b.a, factor);
    break;

  case TCOMBINE_SSBUMP_NOBUMP:
    a.rgb = a.rgb * dot(b.rgb, vec3(2.0 / 3.0));
    break;

  default:
    break;
  }

  return a;
}

#endif // COMMON_FRAG_INC_GLSL
