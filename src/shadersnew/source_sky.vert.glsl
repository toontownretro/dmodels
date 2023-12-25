#version 430

// Two versions:
// COMPRESSED_HDR 0/1
//
// With COMPRESSED_HDR 1, the skybox texture is an HDR texture compressed
// into RGBA8, with the alpha channel being used as a scalar.  Manual bilinear
// interpolation is required.

#pragma combo COMPRESSED_HDR 0 1

uniform mat4 p3d_ModelViewProjectionMatrix;

in vec4 p3d_Vertex;
in vec2 texcoord;

uniform vec3 wspos_view;

uniform mat4 skyTexTransform;

#if COMPRESSED_HDR

uniform vec4 textureSizeInfo;
#define TEXEL_XINCR (textureSizeInfo.x)
#define TEXEL_YINCR (textureSizeInfo.y)
#define U_TO_PIXEL_COORD_SCALE (textureSizeInfo.z)
#define V_TO_PIXEL_COORD_SCALE (textureSizeInfo.w)

out vec2 l_texcoord00;
out vec2 l_texcoord10;
out vec2 l_texcoord01;
out vec2 l_texcoord11;
out vec2 l_texcoord_pixels;

#else // COMPRESSED_HDR

out vec2 l_texcoord;

#endif

void
main() {
  //vec3 skyPos = vec3(0);
  //vec2 texcoord = vec2(0);
  //make_sky_vec(p3d_Vertex.x, p3d_Vertex.z, int(index), skyPos, texcoord);

  gl_Position = p3d_ModelViewProjectionMatrix * p3d_Vertex;

  vec2 vtexcoord = (skyTexTransform * vec4(texcoord, 1, 1)).xy;

#if COMPRESSED_HDR
  l_texcoord00.x = vtexcoord.x - TEXEL_XINCR;
  l_texcoord00.y = vtexcoord.y - TEXEL_YINCR;
  l_texcoord10.x = vtexcoord.x + TEXEL_XINCR;
  l_texcoord10.y = vtexcoord.y - TEXEL_YINCR;
  l_texcoord01.x = vtexcoord.x - TEXEL_XINCR;
  l_texcoord01.y = vtexcoord.y + TEXEL_YINCR;
  l_texcoord11.x = vtexcoord.x + TEXEL_XINCR;
  l_texcoord11.y = vtexcoord.y + TEXEL_YINCR;

  l_texcoord_pixels.xy = l_texcoord00;
  l_texcoord_pixels.x *= U_TO_PIXEL_COORD_SCALE;
  l_texcoord_pixels.y *= V_TO_PIXEL_COORD_SCALE;
#else
  l_texcoord = vtexcoord;
#endif
}
