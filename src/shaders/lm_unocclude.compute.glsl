#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_unocclude.compute.glsl
 * @author lachbr
 * @date 2021-09-24
 */

#define TRACE_NO_ALPHA_TEST 1
#define TRACE_HIT_DIST 1
#define TRACE_NORMAL 1

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f) uniform restrict image2DArray position;
layout(rgba32f) uniform restrict readonly image2DArray unocclude;

uniform ivec3 u_palette_size_page;
#define u_palette_size (u_palette_size_page.xy)
#define u_palette_page (u_palette_size_page.z)
uniform ivec2 u_region_ofs;
uniform vec2 u_bias_;
#define u_bias (u_bias_.x)

void
main() {
  ivec2 palette_pos = ivec2(gl_GlobalInvocationID.xy) + u_region_ofs;
  if (any(greaterThanEqual(palette_pos, u_palette_size))) {
    // Too large, do nothing.
    return;
  }

  ivec3 palette_coord = ivec3(palette_pos, u_palette_page);

  vec4 position_alpha = imageLoad(position, palette_coord);
  if (position_alpha.a < 0.5) {
    return;
  }

  vec3 vertex_pos = position_alpha.xyz;
  vec4 normal_tsize = imageLoad(unocclude, palette_coord);

  vec3 face_normal = normalize(normal_tsize.xyz);
  float texel_size = normal_tsize.w;

  bool is_z = false;
  if (abs(face_normal.x) >= abs(face_normal.y) && abs(face_normal.x) >= abs(face_normal.z)) {

  } else if (abs(face_normal.y) >= abs(face_normal.z)) {

  } else {
    is_z = true;
  }

  vec3 v0 = is_z ? vec3(1, 0, 0) : vec3(0, 0, 1);
  vec3 tangent = normalize(cross(v0, face_normal));
  vec3 bitangent = normalize(cross(tangent, face_normal));
  vec3 base_pos = vertex_pos + face_normal * u_bias; // Raise a bit.

  int start_node_index;
  get_kd_leaf_from_point(base_pos, start_node_index);

  HitData hit_data;

  vec3 rays[4] = vec3[4](tangent, bitangent, -tangent, -bitangent);
  float min_d = 1e20;
  for (int i = 0; i < 4; i++) {
    vec3 ray_to = base_pos + rays[i] * texel_size;

    if (ray_cast(base_pos, ray_to, u_bias,
                 start_node_index, hit_data) == RAY_BACK) {
      if (hit_data.hit_dist < min_d) {
        vertex_pos = base_pos + rays[i] * hit_data.hit_dist + hit_data.normal * u_bias * 160;
        min_d = hit_data.hit_dist;
      }
    }
  }

  position_alpha.xyz = vertex_pos;
  imageStore(position, palette_coord, position_alpha);
}
