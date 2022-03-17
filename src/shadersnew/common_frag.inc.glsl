
#ifndef COMMON_FRAG_INC_GLSL
#define COMMON_FRAG_INC_GLSL

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

  // Gamma to linear on fog color.
  fog_color.rgb = pow(fog_color.rgb, vec3(2.2));

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

#endif // COMMON_FRAG_INC_GLSL
