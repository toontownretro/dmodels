#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_indirect.compute.glsl
 * @author lachbr
 * @date 2021-09-26
 */

// Compute shader for gathering indirect lighting for a luxel.

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Luxel reflectivity.  Direct light * albedo + emission.
// Computed in the direct pass.
uniform sampler2DArray luxel_reflectivity;

uniform sampler2DArray luxel_normal;
uniform sampler2DArray luxel_position;

// Output: indirect lighting at a luxel.
layout(rgba32f) uniform writeonly image2DArray luxel_indirect;
// We accumulate bounce passes here.
layout(rgba32f) uniform image2DArray luxel_indirect_accum;

layout(rgba32f) uniform image2DArray luxel_light;

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

uniform ivec3 u_ray_params;
#define u_ray_from (u_ray_params.x)
#define u_ray_to (u_ray_params.y)
#define u_ray_count (u_ray_params.z)

uint
trace_ray(vec3 p_from, vec3 p_to, out uint r_triangle, out vec3 r_barycentric) {
#if 1
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

  LightmapTri triangle;
  LightmapVertex vert0, vert1, vert2;

  uint iters = 0;
  while (all(greaterThanEqual(icell, ivec3(0))) && all(lessThan(icell, ivec3(u_grid_size))) && iters < 1000) {
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
            hit = backface ? RAY_BACK : RAY_FRONT;
            best_distance = dist;
            r_triangle = tidx;
            r_barycentric = barycentric;
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
        r_triangle = tidx;
        r_barycentric = barycentric;
      }
    }
  }

  if (hit != RAY_MISS) {
    return hit;
  }
#endif



  return RAY_MISS;
}

const float PI = 3.14159265f;
const float GOLDEN_ANGLE = PI * (3.0 - sqrt(5.0));

vec3 vogel_hemisphere(uint p_index, uint p_count, float p_offset) {
	float r = sqrt(float(p_index) + 0.5f) / sqrt(float(p_count));
	float theta = float(p_index) * GOLDEN_ANGLE + p_offset;
	float y = cos(r * PI * 0.5);
	float l = sin(r * PI * 0.5);
	return vec3(l * cos(theta), l * sin(theta), y);
}

float quick_hash(vec2 pos) {
	return fract(sin(dot(pos * 19.19, vec2(49.5791, 97.413))) * 49831.189237);
}

float rand(vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 p){
	vec2 ip = floor(p);
	vec2 u = fract(p);
	u = u*u*(3.0-2.0*u);

	float res = mix(
		mix(rand(ip),rand(ip+vec2(1.0,0.0)),u.x),
		mix(rand(ip+vec2(0.0,1.0)),rand(ip+vec2(1.0,1.0)),u.x),u.y);
	return res*res;
}

void
main() {
  ivec2 palette_pos = ivec2(gl_GlobalInvocationID.xy) + u_region_ofs;
  if (any(greaterThanEqual(palette_pos, u_palette_size))) {
    // Too large, do nothing.
    return;
  }

  //memoryBarrier();

  ivec3 palette_coord = ivec3(palette_pos, u_palette_page);

  vec3 normal = texelFetch(luxel_normal, palette_coord, 0).xyz;
  if (length(normal) < 0.5) {
    return;
  }
  normal = normalize(normal);

  vec3 position = texelFetch(luxel_position, palette_coord, 0).xyz;

  vec3 x;
  if (abs(normal.x) >= abs(normal.y) && abs(normal.x) >= abs(normal.z)) {
    x = vec3(1, 0, 0);
  } else if (abs(normal.y) >= abs(normal.z)) {
    x = vec3(0, 1, 0);
  } else {
    x = vec3(0, 0, 1);
  }

  vec3 v0 = (x == vec3(0, 0, 1)) ? vec3(1, 0, 0) : vec3(0, 0, 1);
  vec3 tangent = normalize(cross(v0, normal));
  vec3 bitangent = normalize(cross(tangent, normal));
  mat3 normal_mat = mat3(tangent, bitangent, normal);

  vec3 light_average = vec3(0);
  float active_rays = 0.0;
  for (uint i = u_ray_from; i < u_ray_to; i++) {
    vec3 ray_dir = normal_mat * vogel_hemisphere(i, u_ray_count, noise(vec2(palette_pos)));

    uint tidx;
    vec3 barycentric;

    vec3 light = vec3(0);
    uint trace_result = trace_ray(position + ray_dir * u_bias,
                                  position + ray_dir * 9999999,
                                  tidx, barycentric);

    if (trace_result == RAY_FRONT) {
      // Hit a triangle.
      LightmapTri tri = get_lightmap_tri(tidx);
      vec2 uv0 = get_lightmap_vertex(tri.indices.x).uv;
      vec2 uv1 = get_lightmap_vertex(tri.indices.y).uv;
      vec2 uv2 = get_lightmap_vertex(tri.indices.z).uv;
      vec3 uvw = vec3(barycentric.x * uv0 + barycentric.y * uv1 + barycentric.z * uv2, float(tri.page));

      // Get reflectivity at the luxel we hit.
      light = textureLod(luxel_reflectivity, uvw, 0.0).rgb;
      active_rays += 1.0;

    }

    light_average += light;
  }

  vec3 light_total;
  if (u_ray_from == 0) {
    light_total = vec3(0.0);

  }else {
    vec4 accum = imageLoad(luxel_indirect_accum, palette_coord);
    light_total = accum.rgb;
    active_rays += accum.a;
  }

  light_total += light_average;

  if (u_ray_to == u_ray_count) {
    if (active_rays > 0) {
      light_total /= active_rays;
    }

    // Store final luxel indirect lighting.
    imageStore(luxel_indirect, palette_coord, vec4(light_total, 1.0));

    vec4 direct = imageLoad(luxel_light, palette_coord);
    direct.rgb += light_total;
    imageStore(luxel_light, palette_coord, direct);

  } else {
    // Keep accumulating.
    imageStore(luxel_indirect_accum, palette_coord, vec4(light_total, active_rays));
  }
}
