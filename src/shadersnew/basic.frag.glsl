#version 330

#pragma combo BASETEXTURE 0 1
#pragma combo ALPHA_TEST 0 1
#pragma combo FOG 0 1
#pragma combo CLIPPING 0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_frag.inc.glsl"

#if BASETEXTURE
in vec2 l_texcoord;
uniform sampler2D base_texture_sampler;
#endif

uniform vec4 p3d_TexAlphaOnly;

in vec4 l_vertex_color;
in vec4 l_eye_position;
in vec4 l_world_position;

out vec4 o_color;

// Alpha testing.
#if ALPHA_TEST
layout(constant_id = 0) const int ALPHA_TEST_MODE = M_none;
layout(constant_id = 1) const float ALPHA_TEST_REF = 0.0;
#endif

// Fog handling

#if FOG
layout(constant_id = 2) const int FOG_MODE = FM_linear;
uniform struct p3d_FogParameters {
  vec4 color;
  float density;
  float start;
  float end;
  float scale; // 1.0 / (end - start)
} p3d_Fog;
#endif

// Clip planes.
#if CLIPPING
uniform vec4 p3d_WorldClipPlane[4];
layout(constant_id = 3) const int NUM_CLIP_PLANES = 0;
#endif

/**
 *
 */
void
main() {
#if CLIPPING
  int clip_plane_count = min(4, NUM_CLIP_PLANES);
  for (int i = 0; i < clip_plane_count; ++i) {
    if (dot(p3d_WorldClipPlane[i], l_world_position) < 0.0) {
      discard;
    }
  }
#endif

  o_color = vec4(1, 1, 1, 1);
#if BASETEXTURE
  o_color *= texture(base_texture_sampler, l_texcoord);
#endif
  o_color += p3d_TexAlphaOnly;
  o_color *= l_vertex_color;

#if ALPHA_TEST
  if (!do_alpha_test(o_color.a, ALPHA_TEST_MODE, ALPHA_TEST_REF)) {
    discard;
  }
#endif

#if FOG
  o_color.rgb = do_fog(o_color.rgb, l_eye_position.xyz, p3d_Fog.color.rgb, p3d_Fog.density,
                       p3d_Fog.end, p3d_Fog.scale, FOG_MODE);
#endif
}
