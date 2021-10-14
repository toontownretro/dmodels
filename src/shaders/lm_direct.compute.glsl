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

// Compute shader for computing direct light into lightmaps.
// Outputs direct lighting that hits a luxel as well as the light that
// should reflect off the surface during the indirect pass.

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f) uniform writeonly image2DArray luxel_direct;
layout(rgba32f) uniform writeonly image2DArray luxel_reflectivity;
uniform sampler2DArray luxel_albedo;
uniform sampler2DArray luxel_position;
uniform sampler2DArray luxel_normal;
uniform sampler2DArray luxel_emission;

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

vec2 rand(vec2 co){
    return vec2(
        fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453),
        fract(cos(dot(co.yx ,vec2(8.64947,45.097))) * 43758.5453)
    )*2.0-1.0;
}

uint
trace_ray(vec3 p_from, vec3 p_to, out float o_distance, out vec3 o_bary) {
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

  uint iters = 0;
  while (all(greaterThanEqual(icell, ivec3(0))) && all(lessThan(icell, ivec3(u_grid_size)))) {
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

        float distance;
        vec3 barycentric;

        if (ray_hits_triangle(p_from, dir, rel_len, u_bias, vtx0, vtx1, vtx2, distance, barycentric)) {
          // Check alpha value at uv coordinate.
          vec3 uvw = vec3(barycentric.x * vert0.uv + barycentric.y * vert1.uv + barycentric.z * vert2.uv, float(triangle.page));
          float alpha = textureLod(luxel_albedo, uvw, 0.0).a;
          // Accept hit if alpha is >= 0.5 so we can do alpha texture shadows.
          if (alpha >= 0.5) {
            o_distance = distance;
            o_bary = barycentric;
            return RAY_CROSS;
          }
        }
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
  for (uint tidx = 0; tidx < num_tris; tidx++) {
    // Ray-box test
    LightmapTri tri = get_lightmap_tri(tidx);
    vec3 t0 = (tri.mins - p_from) * inv_dir;
    vec3 t1 = (tri.maxs - p_from) * inv_dir;
    vec3 tmin = min(t0, t1), tmax = max(t0, t1);

    //if (max(tmin.x, max(tmin.y, tmin.z)) > min(tmax.x, min(tmax.y, tmax.z))) {
      // Ray-box failed.
    //  continue;
    //}

    // Prepare triangle vertices.
    LightmapVertex vert0 = get_lightmap_vertex(tri.indices.x);
    LightmapVertex vert1 = get_lightmap_vertex(tri.indices.y);
    LightmapVertex vert2 = get_lightmap_vertex(tri.indices.z);

    vec3 vtx0 = vert0.position;
    vec3 vtx1 = vert1.position;
    vec3 vtx2 = vert2.position;

    float dist;
    vec3 barycentric;

    if (ray_hits_triangle(p_from, dir, rel_len, u_bias, vtx0, vtx1, vtx2, dist, barycentric)) {
      o_distance = dist;
      o_bary = barycentric;
      return RAY_CROSS; // Any hit good.
    }
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

  //memoryBarrier();

  ivec3 palette_coord = ivec3(palette_pos, u_palette_page);

  vec3 normal = texelFetch(luxel_normal, palette_coord, 0).xyz;
  if (length(normal) < 0.5) {
    // Empty luxel.
    return;
  }
  normal = normalize(normal);
  vec3 position = texelFetch(luxel_position, palette_coord, 0).xyz;

  vec3 albedo = texelFetch(luxel_albedo, palette_coord, 0).xyz;
  vec3 emission = texelFetch(luxel_emission, palette_coord, 0).xyz;


  // Go trhough all lights
  vec3 static_light = vec3(0.0);
  vec3 dynamic_light = vec3(0.0);

  vec4 sh_accum[4] = vec4[4](
    vec4(0.0, 0.0, 0.0, 1.0),
    vec4(0.0, 0.0, 0.0, 1.0),
    vec4(0.0, 0.0, 0.0, 1.0),
    vec4(0.0, 0.0, 0.0, 1.0)
  );

  uint light_count = uint(get_num_lightmap_lights());
  for (uint i = 0; i < light_count; i++) {
    LightmapLight light = get_lightmap_light(i);

    vec3 L;
    float attenuation;
    vec3 light_pos;

    if (light.light_type == LIGHT_TYPE_DIRECTIONAL) {
      attenuation = 1.0;
      L = normalize(-light.dir);
      light_pos = position - light.dir * 9999999;

    } else {
      light_pos = light.pos;
      L = light_pos - position;
      float dist = length(L);
      L = L / dist;

      attenuation = 1.0 / (light.constant + (light.linear * dist) + (light.quadratic * dist * dist));

      if (light.light_type == LIGHT_TYPE_SPOT) {
        float cos_theta = dot(light.dir, -L);
        float spot_atten = (cos_theta - light.stopdot2) * light.oodot;
        spot_atten = max(0.0001, spot_atten);
        spot_atten = pow(spot_atten, light.exponent);
        spot_atten = clamp(spot_atten, 0, 1);
        attenuation *= spot_atten;
      }
    }

    float NdotL = clamp(dot(normal, L), 0.0, 1.0);
    attenuation *= NdotL;

    if (attenuation == 0.0) {
      continue;
    }

    //if (attenuation <= 0.00001) {
    //  continue;
    //}

    float hit_dist;
    vec3 bary;

    /*if (light.light_type == LIGHT_TYPE_POINT || light.light_type == LIGHT_TYPE_SPOT) {
      // For points and spot lights.  Pick several random points along a quad
      // oriented in the direction of the light and trace a ray to each point,
      // averaging the shadow values for all rays.
      float active_rays = 0.0;
      bool is_z = false;
      if (abs(L.x) >= abs(L.y) && abs(L.x) >= abs(L.z)) {

      } else if (abs(L.y) >= abs(L.z)) {

      } else {
        is_z = true;
      }
      vec3 v0 = is_z ? vec3(1, 0, 0) : vec3(0, 0, 1);
      vec3 tangent = normalize(cross(v0, -L));
      vec3 binormal = normalize(cross(tangent, -L));
      for (int j = 0; j < 36; j++) {
        float x = j / 6;
        float y = float(j % 6);
        vec2 ofs = rand(vec2(x, y)) * 8.0;
        vec3 ray_to = light_pos;
        ray_to += tangent * ofs.x;
        ray_to += binormal * ofs.y;
        if (trace_ray(position + (L * u_bias), ray_to, hit_dist, bary) == RAY_MISS) {
          active_rays += 1.0;
        }
      }
      attenuation *= (active_rays / 64.0);
      static_light += attenuation * light.color.rgb;

    } else*/ if (trace_ray(position + (L * u_bias), light_pos, hit_dist, bary) == RAY_MISS) {
      static_light += attenuation * light.color.rgb;
    } //else {
      //static_light += hit_dist;
    //}
  }

  imageStore(luxel_direct, palette_coord, vec4(static_light, 1.0));

  vec3 reflectivity = static_light * albedo + emission;
  imageStore(luxel_reflectivity, palette_coord, vec4(reflectivity, 1.0));
}
