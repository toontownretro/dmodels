#version 330

// 0 is point-eye, 1 is point-world
#pragma combo BILLBOARD_MODE 0 1
#pragma combo ANIMATED 0 1
#pragma combo TRAIL 0 1
#pragma combo DIRECT_LIGHT 0 1
#pragma combo AMBIENT_LIGHT 0 2

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

layout(points) in;
layout(triangle_strip, max_vertices = 4) out;

vec2 corners[4] = vec2[](
  vec2(1, 1),
  vec2(-1, 1),
  vec2(1, -1),
  vec2(-1, -1)
);

uniform mat4 p3d_ProjectionMatrix;
#if (BILLBOARD_MODE == 1) || TRAIL
uniform mat4 p3d_ViewMatrix;
#endif
uniform mat4 p3d_ViewMatrixInverse;
uniform vec2 sprite_size;
uniform mat4 p3d_TextureTransform[1];

in vec4 v_vertex_color[];
in float v_rotate[];
in vec2 v_size[];
#if ANIMATED
flat in int v_anim_frame[];
flat in int v_anim_next_frame[];
flat in float v_anim_frac[];
#endif

out vec2 g_tex_coord;
out vec4 g_vertex_color;
out vec4 g_world_position;
out vec4 g_eye_position;
#if ANIMATED
flat out int g_anim_frame;
flat out int g_anim_next_frame;
flat out float g_anim_frac;
#endif

#if TRAIL
in vec3 v_initial_pos_world[];
in vec3 v_pos_world[];
in vec3 v_prev_pos_world[];
flat in float v_spawn_time[];
uniform vec3 wspos_view;
uniform vec3 u_trail_data;
#define u_min_length (u_trail_data.x)
#define u_max_length (u_trail_data.y)
#define u_length_fade_in_time (u_trail_data.z)
uniform float osg_DeltaFrameTime;
uniform float osg_FrameTime;
#endif

#if DIRECT_LIGHT || AMBIENT_LIGHT
in vec3 v_normal[];
out vec3 g_normal;
#define NORMAL_CURVATURE 0.65
#endif

#if DIRECT_LIGHT
flat in vec3 v_basis_lighting0[];
flat in vec3 v_basis_lighting1[];
flat in vec3 v_basis_lighting2[];
flat in vec3 v_hl2_basis_world0[];
flat in vec3 v_hl2_basis_world1[];
flat in vec3 v_hl2_basis_world2[];
flat out vec3 g_basis_lighting0;
flat out vec3 g_basis_lighting1;
flat out vec3 g_basis_lighting2;
flat out vec3 g_hl2_basis_world0;
flat out vec3 g_hl2_basis_world1;
flat out vec3 g_hl2_basis_world2;
#endif

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

#if TRAIL

  float rad = v_size[0].x;
  vec3 world_pos = v_pos_world[0];
  vec3 prev_world_pos = v_prev_pos_world[0];
  float age = osg_FrameTime - v_spawn_time[0];
  float trail_length = v_size[0].y;
  float length_scale = (age >= u_length_fade_in_time) ? 1.0 : (age / u_length_fade_in_time);

  float initial_pos_len = length(world_pos - v_initial_pos_world[0]);

  vec3 delta = prev_world_pos - world_pos;
  float mag = length(delta);
  delta = normalize(delta);
  float len = length_scale * mag * (1.0/osg_DeltaFrameTime) * trail_length;
  len = max(u_min_length, min(u_max_length, len));
  // Don't render the trail further back than the particle has actually travelled.
  len = min(initial_pos_len, len);

  delta *= len;

  if (len < rad) {
    rad = len;
  }

  vec3 dir_to_beam, tangent_y;
  dir_to_beam = world_pos - wspos_view;
  tangent_y = cross(dir_to_beam, delta);
  tangent_y = normalize(tangent_y);

  vec3 ur = world_pos + (tangent_y * rad * 0.5);
  vec3 lr = world_pos - (tangent_y * rad * 0.5);

  vec3 verts[4] = vec3[](
    lr, ur, lr + delta, ur + delta
  );

  for (int i = 0; i < 4; ++i) {
    vec4 vertex_world_pos = vec4(verts[i], 1);
    vec4 eye_pos = p3d_ViewMatrix * vertex_world_pos;
    gl_Position = p3d_ProjectionMatrix * eye_pos;
    vec2 texcoord = vec2(-corners[i].x * 0.5 + 0.5, corners[i].y * 0.5 + 0.5);
    g_world_position = vertex_world_pos;
    g_eye_position = eye_pos;
    // Apply the texture transform.
    g_tex_coord = (p3d_TextureTransform[0] * vec4(texcoord, 1, 1)).xy;
    g_vertex_color = v_vertex_color[0];
#if ANIMATED
    g_anim_frame = v_anim_frame[0];
    g_anim_next_frame = v_anim_next_frame[0];
    g_anim_frac = v_anim_frac[0];
#endif
    EmitVertex();
  }

#else
  // Emit a quad from the point.
  vec2 sprite_offset = vec2(sprite_size[0], sprite_size[1]);
  sprite_offset *= v_size[0];

  vec3 eyeSpaceUpVector = vec3(0, 0, 1);
  vec3 eyeSpaceRightVector = vec3(1, 0, 0);

#if BILLBOARD_MODE == 1
  // For point-world, the up vector is fixed relative to the world.
  // Move world-space up into eye-space.
  eyeSpaceUpVector = normalize((p3d_ViewMatrix * vec4(0, 0, 1, 0)).xyz);
#endif

  float angle_rad = radians(v_rotate[0]);

  vec2 anim_top_right = sprite_offset;
  vec2 anim_top_left = vec2(-sprite_offset[0], sprite_offset[1]);
  vec2 anim_bot_right = vec2(sprite_offset[0], -sprite_offset[1]);
  vec2 anim_bot_left = -sprite_offset;

  rotate_point(vec2(0), angle_rad, anim_top_right);
  rotate_point(vec2(0), angle_rad, anim_top_left);
  rotate_point(vec2(0), angle_rad, anim_bot_right);
  rotate_point(vec2(0), angle_rad, anim_bot_left);

  // Compute billboarded quad vertices.
  vec3 offsets[4] = vec3[](
    // Top right.
    eyeSpaceRightVector * anim_top_right[0] + eyeSpaceUpVector * anim_top_right[1],
    // Top left.
    eyeSpaceRightVector * anim_top_left[0] + eyeSpaceUpVector * anim_top_left[1],
    // Bottom right.
    eyeSpaceRightVector * anim_bot_right[0] + eyeSpaceUpVector * anim_bot_right[1],
    // Bottom left.
    eyeSpaceRightVector * anim_bot_left[0] + eyeSpaceUpVector * anim_bot_left[1]
  );

  vec3 center_world = (p3d_ViewMatrixInverse * gl_in[0].gl_Position).xyz;

  for (int i = 0; i < 4; i++) {
    // Rotate the offset around (0, 0, 0) for angle animation.

    vec4 eye_pos = gl_in[0].gl_Position;
    eye_pos.xyz -= offsets[i];

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

#if ANIMATED
    g_anim_frame = v_anim_frame[0];
    g_anim_next_frame = v_anim_next_frame[0];
    g_anim_frac = v_anim_frac[0];
#endif

#if DIRECT_LIGHT || AMBIENT_LIGHT
    vec3 world_center_to_corner = g_world_position.xyz - center_world;
    world_center_to_corner = normalize(world_center_to_corner);
    vec3 n = mix(v_normal[0], world_center_to_corner, NORMAL_CURVATURE);
    g_normal = normalize(n);
#endif
#if DIRECT_LIGHT
    g_basis_lighting0 = v_basis_lighting0[0];
    g_basis_lighting1 = v_basis_lighting1[0];
    g_basis_lighting2 = v_basis_lighting2[0];
    g_hl2_basis_world0 = v_hl2_basis_world0[0];
    g_hl2_basis_world1 = v_hl2_basis_world1[0];
    g_hl2_basis_world2 = v_hl2_basis_world2[0];
#endif

    EmitVertex();
  }
#endif
  EndPrimitive();
}
