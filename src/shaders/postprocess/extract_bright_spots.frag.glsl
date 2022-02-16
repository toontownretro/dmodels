#version 430

in vec2 l_texcoord;

uniform sampler2D sourceTexture;
uniform writeonly image2D destTexture;

uniform vec2 bloomStrengthVec;
#define bloomStrength (bloomStrengthVec.x)

const vec3 luminance_weights = vec3(0.2125, 0.7154, 0.0721);

void main() {
  ivec2 coord = ivec2(gl_FragCoord.xy);

  vec3 sceneColor = textureLod(sourceTexture, l_texcoord, 0).rgb;

  float luma = dot(sceneColor, luminance_weights);

  vec3 bloomColor = sceneColor;
  bloomColor *= bloomStrength * 0.005;
  bloomColor = clamp(bloomColor, vec3(0), vec3(25000));

  imageStore(destTexture, coord, vec4(bloomColor, 0.0));
}
