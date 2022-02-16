#version 330

// Two versions:
// COMPRESSED_HDR 0/1
//
// With COMPRESSED_HDR 1, the skybox texture is an HDR texture compressed
// into RGBA8, with the alpha channel being used as a scalar.  Manual bilinear
// interpolation is required.

uniform mat4 p3d_ViewProjectionMatrix;
uniform mat4 p3d_ModelMatrix;

in vec4 p3d_Vertex;

uniform vec3 wspos_view;

uniform mat4 skyTexTransform;

uniform vec2 u_zFar_index;
#define zFar (u_zFar_index.x)
#define index (u_zFar_index.y)

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

#else

out vec2 l_texcoord;

#endif

#define SQRT3INV 0.57735

const ivec3 st_to_vec[6] = ivec3[6](
  ivec3(3,-1,2),
  ivec3(-3,1,2),

  ivec3(1,3,2),
  ivec3(-1,-3,2),

  ivec3(-2,-1,3),
  ivec3(2,-1,-3)
);

// Horizontal sky face texcoords are offset half way up
// so the bottom of the texture is at the horizon line.
const vec2 tex_ofs[6] = vec2[6](
  vec2(0, -0.5),
  vec2(0, -0.5),
  vec2(0, -0.5),
  vec2(0, -0.5),
  vec2(0, 0),
  vec2(0, 0)
);

void
make_sky_vec(float s, float t, int axis, out vec3 position, out vec2 texcoord) {
  float width = zFar * SQRT3INV;

  s = clamp(s, -1.0, 1.0);
  t = clamp(t, -1.0, 1.0);

  vec3 b = vec3(s * width, t * width, width);
  vec3 v = vec3(0);

  for (int j = 0; j < 3; ++j) {
    int k = st_to_vec[axis][j];
    if (k < 0) {
      v[j] = -b[-k - 1];
    } else {
      v[j] = b[k - 1];
    }
    v[j] += wspos_view[j];
  }

  // Avoid bilerp seam.
  s = (s + 1) * 0.5;
  t = (t + 1) * 0.5;

  s = clamp(s, 1.0/512.0, 511.0/512.0);
  t = clamp(t, 1.0/512.0, 511.0/512.0);

  //t = 1.0 - t;
  position = v;
  texcoord = vec2(s, t) + tex_ofs[axis];
}

void
main() {
  vec3 skyPos = vec3(0);
  vec2 texcoord = vec2(0);
  make_sky_vec(p3d_Vertex.x, p3d_Vertex.z, int(index), skyPos, texcoord);

  gl_Position = p3d_ViewProjectionMatrix * vec4(skyPos, 1);

  texcoord = (vec3(texcoord, 1) * mat3(skyTexTransform)).xy;

#if COMPRESSED_HDR
  l_texcoord00.x = texcoord.x - TEXEL_XINCR;
  l_texcoord00.y = texcoord.y - TEXEL_YINCR;
  l_texcoord10.x = texcoord.x + TEXEL_XINCR;
  l_texcoord10.y = texcoord.y - TEXEL_YINCR;
  l_texcoord01.x = texcoord.x - TEXEL_XINCR;
  l_texcoord01.y = texcoord.y + TEXEL_YINCR;
  l_texcoord11.x = texcoord.x + TEXEL_XINCR;
  l_texcoord11.y = texcoord.y + TEXEL_YINCR;

  l_texcoord_pixels.xy = l_texcoord00;
  l_texcoord_pixels.x *= U_TO_PIXEL_COORD_SCALE;
  l_texcoord_pixels.y *= V_TO_PIXEL_COORD_SCALE;
#else
  l_texcoord = texcoord;
#endif
}
