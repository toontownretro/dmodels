#version 330

#pragma combo BASETEXTURE 0 1
#pragma combo CLIPPING 0 1
#pragma combo ALPHA_TEST 0 1
#pragma combo FOG 0 1
#pragma combo ANIMATED 0 1

#pragma skip $[and $[ANIMATED],$[not $[BASETEXTURE]]]

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file spriteParticle.frag.glsl
 * @author brian
 * @date 2021-09-01
 */

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_frag.inc.glsl"

in vec2 g_tex_coord;
in vec4 g_vertex_color;
in vec4 g_world_position;
in vec4 g_eye_position;
#if ANIMATED
flat in int g_anim_frame;
flat in int g_anim_next_frame;
flat in float g_anim_frac;
#endif

out vec4 o_color;

#if BASETEXTURE
#if ANIMATED
uniform sampler2DArray baseTextureSampler;
#else
uniform sampler2D baseTextureSampler;
#endif
#endif

// Alpha testing.
#if ALPHA_TEST
layout(constant_id = 0) const int ALPHA_TEST_MODE = M_none;
layout(constant_id = 1) const float ALPHA_TEST_REF = 0.0;
#endif

// Fog handling.
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

uniform vec4 p3d_TexAlphaOnly;

void
main() {
  // Clipping first!
#if CLIPPING
  int count = min(4, NUM_CLIP_PLANES);
  for (int i = 0; i < count; i++) {
    if (dot(p3d_WorldClipPlane[i], g_world_position) < 0.0) {
      // pixel outside of clip plane interiors
      discard;
    }
  }
#endif

#if BASETEXTURE

#if !ANIMATED
  o_color = texture(baseTextureSampler, g_tex_coord);
#else
  if (g_anim_frame != g_anim_next_frame) {
    vec4 samp0 = texture(baseTextureSampler, vec3(g_tex_coord, g_anim_frame));
    vec4 samp1 = texture(baseTextureSampler, vec3(g_tex_coord, g_anim_next_frame));
    o_color = mix(samp0, samp1, g_anim_frac);
  } else {
    o_color = texture(baseTextureSampler, vec3(g_tex_coord, g_anim_frame));
  }
#endif

#else
  o_color = vec4(1, 1, 1, 1);
#endif

  // Handle alpha-only textures.
  o_color += p3d_TexAlphaOnly;

  o_color *= g_vertex_color;

#if ALPHA_TEST
  if (!do_alpha_test(o_color.a, ALPHA_TEST_MODE, ALPHA_TEST_REF)) {
    discard;
  }
#endif

#if FOG
  o_color.rgb = do_fog(o_color.rgb, g_eye_position.xyz, p3d_Fog.color.rgb, p3d_Fog.density,
                       p3d_Fog.end, p3d_Fog.scale, FOG_MODE);
#endif
}
