#version 430

in vec2 l_texcoord;

uniform sampler2D sourceTexture;
uniform writeonly image2D destTexture;

uniform vec4 curve_threshold;
#define curve (curve_threshold.xyz)
#define threshold (curve_threshold.w)

const vec3 luminance_weights = vec3(0.2125, 0.7154, 0.0721);

void main() {
  ivec2 coord = ivec2(gl_FragCoord.xy);

  vec3 sceneColor = textureLod(sourceTexture, l_texcoord, 0).rgb;

  float br = dot(sceneColor, luminance_weights);

  // Under-threshold: quadratic curve
  float rq = clamp(br - curve.x, 0, curve.y);
  rq = curve.z * rq * rq;

  // Combine and apply the brightness response curve.
  vec3 bloomColor = sceneColor;
  bloomColor *= max(rq, br - threshold) / max(br, 1e-5);

  imageStore(destTexture, coord, vec4(bloomColor, 0.0));
}
