#version 330

#pragma combo COMPRESSED_HDR 0 1

#if COMPRESSED_HDR

in vec2 l_texcoord00;
in vec2 l_texcoord10;
in vec2 l_texcoord01;
in vec2 l_texcoord11;
in vec2 l_texcoord_pixels;

#else // COMPRESSED_HDR

in vec2 l_texcoord;

#endif // COMPRESSED_HDR

uniform sampler2D skySampler;
uniform vec4 p3d_ColorScale;
uniform vec3 skyColorScale;

out vec4 o_color;

void
main() {
#if COMPRESSED_HDR
  // Manual bilinear interpolation for RGBScale compressed HDR
  // skybox texture.
  vec4 s00 = textureLod(skySampler, l_texcoord00, 0);
  vec4 s10 = textureLod(skySampler, l_texcoord10, 0);
  vec4 s01 = textureLod(skySampler, l_texcoord01, 0);
  vec4 s11 = textureLod(skySampler, l_texcoord11, 0);

  vec2 fracCoord = fract(l_texcoord_pixels);

  s00.rgb *= s00.a;
  s10.rgb *= s10.a;

  s00.xyz = mix(s00.xyz, s10.xyz, fracCoord.x);

  s01.rgb *= s01.a;
  s11.rgb *= s11.a;
  s01.xyz = mix(s01.xyz, s11.xyz, fracCoord.x);

  o_color.rgb = mix(s00.xyz, s01.xyz, fracCoord.y);
#else
  o_color.rgb = texture(skySampler, l_texcoord).rgb;
#endif

  o_color.a = 1;
  o_color *= p3d_ColorScale;
  o_color.rgb *= skyColorScale;
}
