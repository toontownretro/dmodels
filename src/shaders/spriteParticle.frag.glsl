#version 330

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
#include "shaders/common_frag.inc.glsl"

in vec2 g_tex_coord;
in vec4 g_vertex_color;
in vec4 g_world_position;

out vec4 o_color;

#ifdef BASETEXTURE
uniform sampler2D baseTextureSampler;
#endif

#if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
uniform vec4 p3d_WorldClipPlane[NUM_CLIP_PLANES];
#endif

uniform vec4 p3d_TexAlphaOnly;

void
main() {
  // Clipping first!
#if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
  for (int i = 0; i < NUM_CLIP_PLANES; i++) {
    if (!ClipPlaneTest(g_world_position, p3d_WorldClipPlane[i])) {
      // pixel outside of clip plane interiors
      discard;
    }
  }
#endif

#ifdef BASETEXTURE
  o_color = texture(baseTextureSampler, g_tex_coord);
#else
  o_color = vec4(1, 1, 1, 1);
#endif

  // Handle alpha-only textures.
  o_color += p3d_TexAlphaOnly;

  o_color *= g_vertex_color;

#ifdef ALPHA_TEST
  if (!AlphaTest(o_color.a)) {
    discard;
  }
#endif
}
