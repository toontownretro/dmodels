#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_direct.compute.glsl
 * @author lachbr
 * @date 2021-09-23
 */

// Shader for computing ambient light probes.

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Probe positions.
uniform samplerBuffer probes;
// Output probe data.
layout(rgba32f) uniform imageBuffer probe_output;

uniform sampler2DArray luxel_light;
uniform sampler2DArray luxel_light_dynamic;
uniform sampler2DArray luxel_albedo;

uniform ivec2 u_grid_size_probe_count;
#define u_grid_size (u_grid_size_probe_count.x)
#define u_probe_count (u_grid_size_probe_count.y)

uniform vec2 u_bias_;
#define u_bias (u_bias_.x)

uniform vec3 u_to_cell_offset;
uniform vec3 u_to_cell_size;

uniform ivec3 u_ray_params;
#define u_ray_from (u_ray_params.x)
#define u_ray_to (u_ray_params.y)
#define u_ray_count (u_ray_params.z)

uniform vec3 u_sky_color;

uint
trace_ray(vec3 p_from, vec3 p_to, out uint r_triangle, out vec3 r_barycentric) {
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
  vec3 delta = min(abs(1.0 / dir_cell), u_grid_size);
  ivec3 step = ivec3(sign(rel_cell));
  vec3 side = (sign(rel_cell) * (vec3(icell) - from_cell) + (sign(rel_cell) * 0.5) + 0.5) * delta;

  LightmapTri triangle;
  LightmapVertex vert0, vert1, vert2;

  uint iters = 0;
  while (all(greaterThanEqual(icell, ivec3(0))) && all(lessThan(icell, ivec3(u_grid_size)))) {
    uvec2 cell_data = texelFetch(grid, icell, 0).xy;
    if (cell_data.x > 0) { // Triangle here.
      uint hit = RAY_MISS;
      float best_distance = 1e20;

      for (uint i = 0; i < cell_data.x; i++) {
        uint tidx = get_tri_for_cell(int(cell_data.y + i));

        // Ray-box test
        get_lightmap_tri(tidx, triangle);
        vec3 t0 = (triangle.mins - p_from) * inv_dir;
        vec3 t1 = (triangle.maxs - p_from) * inv_dir;
        vec3 tmin = min(t0, t1), tmax = max(t0, t1);

        if (max(tmin.x, max(tmin.y, tmin.z)) > min(tmax.x, min(tmax.y, tmax.z))) {
          // Ray-box failed.
          continue;
        }

        // Prepare triangle vertices.
        get_lightmap_vertex(triangle.indices.x, vert0);
        get_lightmap_vertex(triangle.indices.y, vert1);
        get_lightmap_vertex(triangle.indices.z, vert2);

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
            // Check alpha value at uv coordinate.
            vec3 uvw = vec3(barycentric.x * vert0.uv + barycentric.y * vert1.uv + barycentric.z * vert2.uv, float(triangle.page));
            float alpha = textureLod(luxel_albedo, uvw, 0.0).a;
            // Accept hit if alpha is >= 0.5 so we can do alpha texture shadows.
            if (alpha >= 0.5) {
              hit = backface ? RAY_BACK : RAY_FRONT;
              best_distance = dist;
              r_triangle = tidx;
              r_barycentric = barycentric;
            }
          }
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
  return RAY_MISS;
}

void
main() {
  int probe_index = int(gl_GlobalInvocationID.x);
  if (probe_index >= u_probe_count) {
    return;
  }

  vec3 position = texelFetch(probes, probe_index).xyz;

  vec4 probe_sh_accum[9] = vec4[](
    vec4(0.0),
    vec4(0.0),
    vec4(0.0),
    vec4(0.0),
    vec4(0.0),
    vec4(0.0),
    vec4(0.0),
    vec4(0.0),
    vec4(0.0)
  );

  uint noise = random_seed(ivec3(u_ray_from, probe_index, 49502741));
  for (uint i = u_ray_from; i < u_ray_to; i++) {
    vec3 ray_dir = generate_hemisphere_uniform_direction(noise);
    if (bool(i & 1)) {
      // Throw to both sides, so alternate them.
      ray_dir.z *= -1.0;
    }

    uint tidx;
    vec3 barycentric;
    vec3 light = vec3(0.0);

    uint trace_result = trace_ray(position + ray_dir * u_bias, position + ray_dir * 9999999, tidx, barycentric);
    if (trace_result == RAY_FRONT) {
      LightmapTri tri = get_lightmap_tri(tidx);
      vec2 uv0 = get_lightmap_vertex(tri.indices.x).uv;
      vec2 uv1 = get_lightmap_vertex(tri.indices.y).uv;
      vec2 uv2 = get_lightmap_vertex(tri.indices.z).uv;
      vec3 uvw = vec3(barycentric.x * uv0 + barycentric.y * uv1 + barycentric.z * uv2, float(tri.page));

      light = textureLod(luxel_light, uvw, 0.0).rgb;
      light += textureLod(luxel_light_dynamic, uvw, 0.0).rgb;

    } else if (trace_result == RAY_MISS) {
      light = u_sky_color;
    }

    {
      float c[9] = float[](
        0.282095, //l0
        0.488603 * ray_dir.y, //l1n1
        0.488603 * ray_dir.z, //l1n0
        0.488603 * ray_dir.x, //l1p1
        1.092548 * ray_dir.x * ray_dir.y, //l2n2
        1.092548 * ray_dir.y * ray_dir.z, //l2n1
        //0.315392 * (ray_dir.x * ray_dir.x + ray_dir.y * ray_dir.y + 2.0 * ray_dir.z * ray_dir.z), //l20
        0.315392 * (3.0 * ray_dir.z * ray_dir.z - 1.0), //l20
        1.092548 * ray_dir.x * ray_dir.z, //l2p1
        0.546274 * (ray_dir.x * ray_dir.x - ray_dir.y * ray_dir.y) //l2p2
      );

      for (uint j = 0; j < 9; j++) {
        probe_sh_accum[j].rgb += light * c[j];
      }
    }
  }

  if (u_ray_from > 0) {
    for (uint j = 0; j < 9; j++) {
      probe_sh_accum[j] += imageLoad(probe_output, int(probe_index * 9 + j));
    }
  }

  if (u_ray_to == u_ray_count) {
    for (uint j = 0; j < 9; j++) {
      probe_sh_accum[j] *= 4.0 / float(u_ray_count);
    }
  }

  for (uint j = 0; j < 9; j++) {
    imageStore(probe_output, int(probe_index * 9 + j), probe_sh_accum[j]);
  }
}
