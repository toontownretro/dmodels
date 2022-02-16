#version 430

in vec2 l_texcoord;

uniform ivec2 mip_first;
#define mip (mip_first.x)
#define first (mip_first.y)

uniform sampler2D sourceTexture;
uniform writeonly image2D destTexture;

void main() {
  vec2 sourceSize = vec2(textureSize(sourceTexture, mip).xy);
  vec3 summed = textureLod(sourceTexture, l_texcoord, mip + 1).xyz;

  if (first == 1) {
    summed = vec3(0);
  }

  // Upsample texture.
  ivec2 coord = ivec2(gl_FragCoord.xy);

  vec2 fltCoord = vec2(coord) / (2.0 * sourceSize);
  vec2 texelSize = 1.0 / sourceSize;

  vec3 c0 = textureLod(sourceTexture, fltCoord + vec2(-1, -1) * texelSize, mip).rgb;
  vec3 c1 = textureLod(sourceTexture, fltCoord + vec2(0, -1) * texelSize, mip).rgb;
  vec3 c2 = textureLod(sourceTexture, fltCoord + vec2(1, -1) * texelSize, mip).rgb;
  vec3 c3 = textureLod(sourceTexture, fltCoord + vec2(-1, 0) * texelSize, mip).rgb;
  vec3 c4 = textureLod(sourceTexture, fltCoord, mip).rgb;
  vec3 c5 = textureLod(sourceTexture, fltCoord + vec2(1, 0) * texelSize, mip).rgb;
  vec3 c6 = textureLod(sourceTexture, fltCoord + vec2(-1, 1) * texelSize, mip).rgb;
  vec3 c7 = textureLod(sourceTexture, fltCoord + vec2(0, 1) * texelSize, mip).rgb;
  vec3 c8 = textureLod(sourceTexture, fltCoord + vec2(1, 1) * texelSize, mip).rgb;

  vec3 result = 0.0625 * (c0 + 2 * c1 + c2 + 2 * c3 + 4 * c4 + 2 * c5 + c6 + 2 * c7 + c8);

  vec3 passResult = summed + result;
  passResult *= 0.5;

  vec4 oldData = texelFetch(sourceTexture, coord, mip - 1);
  imageStore(destTexture, coord, oldData + vec4(result, 0));
}
