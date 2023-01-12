#version 330

#pragma combo BASETEXTURE 0 1
#pragma combo HAS_ALPHA 0 1
#pragma combo CLIPPING 0 1

// We only care about the basetexture if alpha is enabled.
#pragma skip $[and $[not $[HAS_ALPHA]],$[BASETEXTURE]]

/**
 * @file csmdepth.frag.glsl
 * @author brian
 * @date 2020-10-30
 */

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_frag.inc.glsl"

in vec3 v_texcoord_alpha;
in vec4 v_worldPosition;

// Clip planes.
#if CLIPPING
uniform vec4 p3d_WorldClipPlane[4];
layout(constant_id = 0) const int NUM_CLIP_PLANES = 0;
#endif

#if BASETEXTURE
uniform sampler2D baseTextureSampler;
#endif

#if HAS_ALPHA
layout(constant_id = 1) const int ALPHA_TEST_MODE = 7;
layout(constant_id = 2) const float ALPHA_TEST_REF = 0.5;
#endif

void main() {
#if CLIPPING
  int clip_plane_count = min(4, NUM_CLIP_PLANES);
  for (int i = 0; i < clip_plane_count; ++i) {
    if (dot(p3d_WorldClipPlane[i], v_worldPosition) < 0.0) {
      discard;
    }
  }
#endif

#if HAS_ALPHA
#if BASETEXTURE
  float alpha = texture(baseTextureSampler, v_texcoord_alpha.xy).a;
  alpha *= v_texcoord_alpha.z;
#else
  float alpha = v_texcoord_alpha.z;
#endif

  if (!do_alpha_test(alpha, ALPHA_TEST_MODE, ALPHA_TEST_REF)) {
    discard;
  }
#endif
}
