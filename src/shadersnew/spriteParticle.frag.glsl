#version 330

#pragma combo BASETEXTURE 0 1
#pragma combo CLIPPING 0 1
#pragma combo ALPHA_TEST 0 1
#pragma combo FOG 0 1
#pragma combo ANIMATED 0 1
#pragma combo DIRECT_LIGHT 0 1
#pragma combo AMBIENT_LIGHT 0 2

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

layout(constant_id = 4) const int BLEND_MODE = 0;

uniform vec4 p3d_TexAlphaOnly;

#if DIRECT_LIGHT || AMBIENT_LIGHT
in vec3 g_normal;
#endif

#if DIRECT_LIGHT
flat in vec3 g_basis_lighting0;
flat in vec3 g_basis_lighting1;
flat in vec3 g_basis_lighting2;
flat in vec3 g_hl2_basis_world0;
flat in vec3 g_hl2_basis_world1;
flat in vec3 g_hl2_basis_world2;
#endif

#if AMBIENT_LIGHT == 1
uniform struct {
  vec4 ambient;
} p3d_LightModel;
#elif AMBIENT_LIGHT == 2
uniform vec3 ambientProbe[9];
#endif // AMBIENT_LIGHT

vec3 ambientLookup(vec3 wnormal) {
#if AMBIENT_LIGHT == 2
  return sample_l2_ambient_probe(ambientProbe, wnormal);

#elif AMBIENT_LIGHT == 1
  return p3d_LightModel.ambient.rgb;

#elif DIRECT_LIGHT
  return vec3(0.0);

#else
  return vec3(1.0);
#endif
}

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

  if (BLEND_MODE == 2) {
    o_color.rgb *= o_color.a;
  } else if (BLEND_MODE == 1) {
    o_color.rgb = mix(vec3(0.5), o_color.rgb, o_color.a);
  }

#if DIRECT_LIGHT || AMBIENT_LIGHT

  if (BLEND_MODE == 0) {
    vec3 n = normalize(g_normal);
    vec3 lighting = ambientLookup(n);
    //vec3 lighting = vec3(0);

#if DIRECT_LIGHT
    vec3 w = clamp(vec3(dot(n, g_hl2_basis_world0), dot(n, g_hl2_basis_world1), dot(n, g_hl2_basis_world2)), 0, 1);
    lighting += g_basis_lighting0 * w.x + g_basis_lighting1 * w.y + g_basis_lighting2 * w.z;
#endif

    //o_color.rgb = lighting;

    o_color.rgb *= lighting;
  }

#endif

#if ALPHA_TEST
  if (!do_alpha_test(o_color.a, ALPHA_TEST_MODE, ALPHA_TEST_REF)) {
    discard;
  }
#endif

#if FOG
  vec3 fog_color;
  if (BLEND_MODE == 2) {
    // Additive blending, we need black fog.
    fog_color = vec3(0.0);
  } else if (BLEND_MODE == 1) {
    // Modulate blending, we need gray fog.
    fog_color = vec3(0.5);
  } else {
    // Gamma-correct the fog color.
    fog_color = pow(p3d_Fog.color.rgb, vec3(2.2));
  }
  o_color.rgb = do_fog(o_color.rgb, g_eye_position.xyz, fog_color, p3d_Fog.density,
                       p3d_Fog.end, p3d_Fog.scale, FOG_MODE);
#endif
}
