#version 330

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
#include "shaders/common.inc.glsl"

uniform mat4 p3d_ModelViewMatrix;
uniform vec4 p3d_ColorScale;

in vec4 p3d_Vertex;
in vec4 p3d_Color;

in float rotate;
in vec2 size;

out vec4 v_vertex_color;
out float v_rotate;
out vec2 v_size;

void
main() {
  gl_Position = p3d_ModelViewMatrix * p3d_Vertex;
  v_rotate = rotate;
  v_size = size;

  vec4 color_scale = p3d_ColorScale;
  vec4 vertex_color = p3d_Color;
  GammaToLinear(color_scale);
  GammaToLinear(vertex_color);
  v_vertex_color = vertex_color * color_scale;
}
