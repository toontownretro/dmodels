#version 330

#pragma combo ANIMATED 0 1

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file spriteParticle.vert.glsl
 * @author brian
 * @date 2021-09-01
 */

// This is a shader that is specific to rendering sprite particles.  It
// emulates fixed-function OpenGL point sprites.

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common.inc.glsl"

uniform mat4 p3d_ModelViewMatrix;
uniform vec4 p3d_ColorScale;

in vec4 p3d_Vertex;
in vec4 p3d_Color;

in float rotate;
in vec2 size;

#if ANIMATED
in vec4 anim_data;
in vec3 anim_data2;
#define anim_index int(anim_data.x)
#define anim_fps (anim_data.y)
#define anim_particle_spawn_time (anim_data.z)
#define anim_first_frame int(anim_data.w)
#define anim_num_frames int(anim_data2.x)
#define anim_loop bool(anim_data2.y)
#define anim_interp bool(anim_data2.z)

flat out int v_anim_frame;
flat out int v_anim_next_frame;
flat out float v_anim_frac;
uniform float osg_FrameTime;
#endif

out vec4 v_vertex_color;
out float v_rotate;
out vec2 v_size;

void
main() {
  gl_Position = p3d_ModelViewMatrix * p3d_Vertex;
  v_rotate = rotate;
  v_size = size;

#if ANIMATED
  float elapsed = osg_FrameTime - anim_particle_spawn_time;
  float fframe = elapsed * anim_fps;
  int frame = int(fframe);
  if (anim_loop) {
    frame %= anim_num_frames;
  } else {
    frame = min(frame, anim_num_frames - 1);
  }
  int next_frame = frame + 1;
  if (anim_loop) {
    next_frame %= anim_num_frames;
  } else {
    next_frame = min(next_frame, anim_num_frames - 1);
  }

  v_anim_frame = frame + anim_first_frame;
  if (anim_interp) {
    v_anim_next_frame = next_frame + anim_first_frame;
  } else {
    v_anim_next_frame = v_anim_frame;
  }
  v_anim_frac = fframe - int(fframe);
#endif

  vec4 color_scale = p3d_ColorScale;
  vec4 vertex_color = p3d_Color;
  GammaToLinear(color_scale);
  GammaToLinear(vertex_color);
  v_vertex_color = vertex_color * color_scale;
}
