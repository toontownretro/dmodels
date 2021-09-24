/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_compute.inc.glsl
 * @author lachbr
 * @date 2021-09-23
 */

#include "shaders/lm_buffers.inc.glsl"

/**
 * Returns true if the given ray intersects the given triangle.
 * Fills in intersection distance and barycentric coordinates.
 */
bool
ray_hits_triangle(vec3 from, vec3 dir, float max_dist, float bias, vec3 p0,
                  vec3 p1, vec3 p2, out float dist, out vec3 barycentric) {
  const vec3 e0 = p1 - p0;
  const vec3 e1 = p0 - p2;
  vec3 triangle_normal = cross(e1, e0);

  float n_dot_dir = dot(triangle_normal, dir);

  if (abs(n_dot_dir) < 0.01) {
    return false;
  }

  const vec3 e2 = (p0 - from) / n_dot_dir;
  const vec3 i = cross(dir, e2);

  barycentric.y = dot(i, e1);
  barycentric.z = dot(i, e0);
  barycentric.x = 1.0 - (barycentric.z + barycentric.y);
  dist = dot(triangle_normal, e2);

  return (dist > bias) && (dist < max_dist) && all(greaterThanEqual(barycentric, vec3(0.0)));
}

#define RAY_MISS 0
#define RAY_FRONT 1
#define RAY_BACK 2
#define RAY_CROSS 3
