#version 430

in vec2 l_texcoord;

uniform sampler2D sceneTexture;

out vec4 o_color;

vec3 uncharted2TonemapPartial(vec3 x) {
  float A = 0.15;
  float B = 0.50;
  float C = 0.10;
  float D = 0.20;
  float E = 0.02;
  float F = 0.30;
  return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

void main() {
  o_color = textureLod(sceneTexture, l_texcoord, 0);
  vec3 curr = uncharted2TonemapPartial(o_color.rgb);
  vec3 W = vec3(11.2);
  vec3 whiteScale = vec3(1.0) / uncharted2TonemapPartial(W);
  o_color.rgb = curr * whiteScale;
}
