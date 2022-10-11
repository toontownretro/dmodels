#version 430

in vec2 l_texcoord;

uniform sampler2D sceneTexture;
uniform vec4 params0;
uniform vec2 params1;

out vec4 o_color;

vec3 Tonemap_Uchimura(vec3 x, float P, float a, float m, float l, float c, float b) {
  // Uchimura 2017, "HDR theory and practice"
  // Math: https://www.desmos.com/calculator/gslcdxvipg
  // Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
  float l0 = ((P - m) * l) / a;
  float L0 = m - m / a;
  float L1 = m + (1.0 - m) / a;
  float S0 = m + l0;
  float S1 = m + a * l0;
  float C2 = (a * P) / (P - S1);
  float CP = -C2 / P;

  vec3 w0 = vec3(1.0 - smoothstep(0.0, m, x));
  vec3 w2 = vec3(step(m + l0, x));
  vec3 w1 = vec3(1.0 - w0 - w2);

  vec3 T = vec3(m * pow(x / m, vec3(c)) + b);
  vec3 S = vec3(P - (P - S1) * exp(CP * (x - S0)));
  vec3 L = vec3(m + a * (x - m));

  return T * w0 + L * w1 + S * w2;
}

vec3 Tonemap_Uchimura(vec3 x) {
  const float P = params0.x;//1.0;  // max display brightness
  const float a = params0.y;//1.0;  // contrast
  const float m = params0.z;//0.22; // linear section start
  const float l = params0.w;//0.4;  // linear section length
  const float c = params1.x;//1.33; // black
  const float b = params1.y;//0.0;  // pedestal
  return Tonemap_Uchimura(x, P, a, m, l, c, b);
}

void main() {
  o_color = textureLod(sceneTexture, l_texcoord, 0);
  o_color.rgb = clamp(Tonemap_Uchimura(o_color.rgb), 0, 1);
}
