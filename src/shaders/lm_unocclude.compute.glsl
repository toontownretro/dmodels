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

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f) uniform restrict image2DArray position;
layout(rgba32f) uniform restrict readonly image2DArray unocclude;

uniform ivec3 u_palette_size_page;
#define u_palette_size (u_palette_size_page.xy)
#define u_palette_page (u_palette_size_page.z)
uniform ivec3 u_region_ofs_grid_size;
#define u_region_ofs (u_region_ofs_grid_size.xy)
#define u_grid_size (u_region_ofs_grid_size.z)
uniform vec2 u_bias_;
#define u_bias (u_bias_.x)
uniform vec3 u_to_cell_offset;
uniform vec3 u_to_cell_size;

uint
trace_ray(vec3 p_from, vec3 p_to, out float r_distance, out vec3 r_normal) {
#if 0
  vec3 rel = p_to - p_from;
  float rel_len = length(rel);
  vec3 dir = normalize(rel);
  vec3 inv_dir = 1.0 / dir;

  vec3 from_cell = (p_from - u_to_cell_offset) * u_to_cell_size;
  vec3 to_cell = (p_to - u_to_cell_offset) * u_to_cell_size;

  vec3 rel_cell = to_cell - from_cell;
  ivec3 icell = ivec3(from_cell);
  ivec3 iendcell = ivec3(to_cell);
  vec3 dir_cell = normalize(rel_cell);
  vec3 delta = abs(1.0 / dir_cell);
  ivec3 step = ivec3(sign(rel_cell));
  vec3 side = (sign(rel_cell) * (vec3(icell) - from_cell) + (sign(rel_cell) * 0.5) + 0.5) * delta;

  uint iters = 0;
  while (all(greaterThanEqual(icell, ivec3(0))) && all(lessThan(icell, ivec3(u_grid_size))) && iters < 1000) {
    uvec2 cell_data = texelFetch(grid, icell, 0).xy;
    if (cell_data.x > 0) { // Triangle here.
      uint hit = RAY_MISS;
      float best_distance = 1e20;

      for (uint i = 0; i < cell_data.x; i++) {
        uint tidx = get_tri_for_cell(int(cell_data.y + i));

        // Ray-box test
        LightmapTri triangle = get_lightmap_tri(tidx);
        vec3 t0 = (triangle.mins - p_from) * inv_dir;
        vec3 t1 = (triangle.maxs - p_from) * inv_dir;
        vec3 tmin = min(t0, t1), tmax = max(t0, t1);

        if (max(tmin.x, max(tmin.y, tmin.z)) > min(tmax.x, min(tmax.y, tmax.z))) {
          // Ray-box failed.
          continue;
        }

        // Prepare triangle vertices.
        LightmapVertex vert0 = get_lightmap_vertex(triangle.indices.x);
        LightmapVertex vert1 = get_lightmap_vertex(triangle.indices.y);
        LightmapVertex vert2 = get_lightmap_vertex(triangle.indices.z);

        vec3 vtx0 = vert0.position;
        vec3 vtx1 = vert1.position;
        vec3 vtx2 = vert2.position;

        ///
        vec3 normal = -normalize(cross(vtx0 - vtx1, vtx0 - vtx2));
        bool backface = dot(normal, dir) >= 0.0;
        ///

        float distance;
        vec3 barycentric;

        if (ray_hits_triangle(p_from, dir, rel_len, u_bias, vtx0, vtx1, vtx2, distance, barycentric)) {
          ///
          if (!backface) {
            distance = max(u_bias, distance - u_bias);
          }

          if (distance < best_distance) {
            hit = backface ? RAY_BACK : RAY_FRONT;
            best_distance = distance;
            r_distance = distance;
            r_normal = normal;
          }
          ///
        }
      }

      if (hit != RAY_MISS) {
        return hit;
      }
    }

    if (icell == iendcell) {
      break;
    }

    bvec3 mask = lessThanEqual(side.xyz, min(side.yzx, side.zxy));
    side += vec3(mask) * delta;
    icell += ivec3(vec3(mask)) * step;

    iters++;
  }
#else
  vec3 rel = p_to - p_from;
  float rel_len = length(rel);
  vec3 dir = normalize(rel);
  vec3 inv_dir = 1.0 / dir;

  uint num_tris = get_num_lightmap_tris();
  uint hit = RAY_MISS;
  float best_distance = 1e20;
  LightmapTri tri;
  LightmapVertex vert0, vert1, vert2;
  for (uint tidx = 0; tidx < num_tris; tidx++) {
    // Ray-box test
    get_lightmap_tri(tidx, tri);
    vec3 t0 = (tri.mins - p_from) * inv_dir;
    vec3 t1 = (tri.maxs - p_from) * inv_dir;
    vec3 tmin = min(t0, t1), tmax = max(t0, t1);

    if (max(tmin.x, max(tmin.y, tmin.z)) > min(tmax.x, min(tmax.y, tmax.z))) {
      // Ray-box failed.
      continue;
    }

    // Prepare triangle vertices.
    get_lightmap_vertex(tri.indices.x, vert0);
    get_lightmap_vertex(tri.indices.y, vert1);
    get_lightmap_vertex(tri.indices.z, vert2);

    vec3 vtx0 = vert0.position;
    vec3 vtx1 = vert1.position;
    vec3 vtx2 = vert2.position;

    vec3 normal = normalize(cross(vtx1 - vtx0, vtx2 - vtx0));
    bool backface = dot(normal, dir) >= 0.0;

    float dist;
    vec3 barycentric;

    if (ray_hits_triangle(p_from, dir, rel_len, u_bias, vtx0, vtx1, vtx2, dist, barycentric)) {
      if (!backface) {
        dist = max(u_bias, dist - u_bias);
      }

      if (dist < best_distance) {
        hit = backface ? RAY_BACK : RAY_FRONT;
        best_distance = dist;
        r_distance = dist;
        r_normal = normal;
      }
    }
  }

  if (hit != RAY_MISS) {
    return hit;
  }
#endif

  return RAY_MISS;
}

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

  vec3 face_normal = normal_tsize.xyz;
  float texel_size = normal_tsize.w;

  vec3 x;
  if (abs(normal.x) >= abs(normal.y) && abs(normal.x) >= abs(normal.z)) {
    x = vec3(1, 0, 0);
  } else if (abs(normal.y) >= abs(normal.z)) {
    x = vec3(0, 1, 0);
  } else {
    x = vec3(0, 0, 1);
  }

  vec3 v0 = (x == vec3(0, 0, 1)) ? vec3(1, 0, 0) : vec3(0, 0, 1);
  vec3 tangent = normalize(cross(v0, face_normal));
  vec3 bitangent = normalize(cross(tangent, face_normal));
  vec3 base_pos = vertex_pos + face_normal * u_bias; // Raise a bit.

  vec3 rays[4] = vec3[4](tangent, bitangent, -tangent, -bitangent);
  float min_d = 1e20;
  for (int i = 0; i < 4; i++) {
    vec3 ray_to = base_pos + rays[i] * texel_size;
    float d;
    vec3 norm;

    if (trace_ray(base_pos, ray_to, d, norm) == RAY_FRONT) {
      if (d < min_d) {
        vertex_pos = base_pos + rays[i] * d + norm * u_bias * 10.0;
        min_d = d;
      }
    }
  }

  position_alpha.xyz = vertex_pos;
  imageStore(position, palette_coord, position_alpha);
}
