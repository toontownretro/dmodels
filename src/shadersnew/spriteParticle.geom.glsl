#version 330

#pragma combo BLAH 0 1

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file spriteParticle.geom.glsl
 * @author brian
 * @date 2021-09-01
 */

// This shader takes in a point sprite and converts it to a quad for rendering
// on the fly.

vec2 corners[4] = vec2[](
  vec2(1, 1),
  vec2(-1, 1),
  vec2(1, -1),
  vec2(-1, -1)
);

layout(points) in;
layout(triangle_strip, max_vertices = 4) out;

uniform mat4 p3d_ProjectionMatrix;
uniform mat4 p3d_ViewMatrixInverse;
uniform vec2 sprite_size;
uniform mat4 p3d_TextureTransform[1];

in vec4 v_vertex_color[];
in float v_rotate[];
in vec2 v_size[];

out vec2 g_tex_coord;
out vec4 g_vertex_color;
out vec4 g_world_position;
out vec4 g_eye_position;

/**
 * Rotates the indicated point angle degrees around center.
 */
void
rotate_point(vec2 center, float angle, inout vec2 point) {
  float s = sin(angle);
  float c = cos(angle);

  // Translate point back to origin.
  point.x -= center.x;
  point.y -= center.y;

  // Rotate point.
  float x_new = point.x * c - point.y * s;
  float z_new = point.x * s + point.y * c;

  // Translate point back.
  point.x = x_new + center.x;
  point.y = z_new + center.y;
}

void
main() {
  // Emit a quad from the point.
  vec2 sprite_offset = vec2(sprite_size[0], sprite_size[1]);
  sprite_offset *= v_size[0];

  float angle_rad = radians(v_rotate[0]);
  for (int i = 0; i < 4; i++) {
    vec4 eye_pos = gl_in[0].gl_Position;
    eye_pos.xz -= sprite_offset * corners[i];

    // Apply angle animation.
    rotate_point(gl_in[0].gl_Position.xz, angle_rad, eye_pos.xz);

    // Emit quad corner position and texture coordinate.
    gl_Position = p3d_ProjectionMatrix * eye_pos;

    g_world_position = p3d_ViewMatrixInverse * eye_pos;
    g_eye_position = eye_pos;

    vec2 texcoord = vec2(-corners[i].x * 0.5 + 0.5, corners[i].y * 0.5 + 0.5);

    // Apply the texture transform.
    g_tex_coord = (p3d_TextureTransform[0] * vec4(texcoord, 1, 1)).xy;

    g_vertex_color = v_vertex_color[0];

    EmitVertex();
  }
  EndPrimitive();
}
