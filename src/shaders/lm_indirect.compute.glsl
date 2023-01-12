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
 * @author brian
 * @date 2021-09-26
 */

// Compute shader for gathering indirect lighting for a luxel.

#define TRACE_MODE_INDIRECT 1

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Luxel reflectivity.  On bounce 0, contains direct light * albedo + emission.
// Subsequent bounces contain gathered light from previous bounce.
uniform sampler2DArray luxel_reflectivity;
// Gathered light.
layout(rgba32f) uniform image2DArray luxel_gathered;
layout(rgba32f) uniform image2DArray luxel_sh_gathered;
// Contains just direct light at start, gathered added onto this.
layout(rgba32f) uniform image2DArray luxel_light;

// This stores the total amount of light we added on this bounce.
// This is read back on the CPU to determine when the lighting has
// stabilized.
layout(r32ui) uniform uimage1D feedback_total_add;

uniform sampler2DArray luxel_albedo;
uniform sampler2DArray luxel_normal;
uniform sampler2DArray luxel_position;

// Also reflect light off of vertex-lit geometry.
uniform sampler2D vtx_reflectivity;
uniform sampler2D vtx_albedo;
// X: LightmapVertex index of first vertex-lit vertex.
// Y: Width of the vertex palette.
uniform uvec2 u_vtx_lit_info;

uniform ivec4 u_palette_size_page_bounce;
#define u_palette_size (u_palette_size_page_bounce.xy)
#define u_palette_page (u_palette_size_page_bounce.z)
#define u_bounce (u_palette_size_page_bounce.w)
uniform vec2 u_bias_;
#define u_bias (u_bias_.x)

uniform ivec2 u_region_ofs;

uniform ivec3 u_ray_params;
#define u_ray_from (u_ray_params.x)
#define u_ray_to (u_ray_params.y)
#define u_ray_count (u_ray_params.z)

uniform vec3 u_sky_color;

#define PI 3.141592653589793

void
main() {
  ivec2 palette_pos = ivec2(gl_GlobalInvocationID.xy) + u_region_ofs;
  if (any(greaterThanEqual(palette_pos, u_palette_size))) {
    // Too large, do nothing.
    return;
  }

  ivec3 palette_coord = ivec3(palette_pos, u_palette_page);

  vec3 normal = texelFetch(luxel_normal, palette_coord, 0).xyz;
  if (length(normal) < 0.5) {
    return;
  }

  normal = normalize(normal);

  vec3 position = texelFetch(luxel_position, palette_coord, 0).xyz;

  vec3 x;
  bool is_z = false;
  if (abs(normal.x) >= abs(normal.y) && abs(normal.x) >= abs(normal.z)) {

  } else if (abs(normal.y) >= abs(normal.z)) {

  } else {
    is_z = true;
  }

  int start_node_index;
  get_kd_leaf_from_point(position + normal * u_bias, start_node_index);

  vec3 v0 = is_z ? vec3(1, 0, 0) : vec3(0, 0, 1);
  vec3 tangent = normalize(cross(v0, normal));
  vec3 bitangent = normalize(cross(tangent, normal));
  mat3 normal_mat = mat3(tangent, bitangent, normal);

  HitData hit_data;

  vec4 sh_accum[4] = vec4[](
    vec4(0.0, 0.0, 0.0, 1.0),
    vec4(0.0, 0.0, 0.0, 1.0),
    vec4(0.0, 0.0, 0.0, 1.0),
    vec4(0.0, 0.0, 0.0, 1.0));

  vec3 gathered = vec3(0);
  float total_dot = 0.0;
  float active_rays = 0.0;
  uint noise = random_seed(ivec3(u_ray_from, palette_pos));
  for (uint i = u_ray_from; i < u_ray_to; i++) {
    vec3 ray_dir = normal_mat * generate_hemisphere_cosine_weighted_direction(noise);
    ray_dir = normalize(ray_dir);

    float dt = dot(normal, ray_dir);
    if (dt <= 0.0) {
      continue;
    }

    total_dot += dt;
    active_rays += 1.0;

    vec3 barycentric;

    vec3 light = vec3(0);
    uint trace_result = ray_cast(position + normal * u_bias,
                                 position + ray_dir * 9999999,
                                 u_bias,
                                 luxel_albedo,
                                 start_node_index,
                                 hit_data);

    if (trace_result == RAY_FRONT) {

      // Hit a triangle.
      if ((hit_data.tri.flags & TRIFLAGS_SKY) != 0) {
        // Hit sky.  Bring in sky ambient color, but only on the first bounce.
        if (u_bounce == 0) {
          light = u_sky_color;
        }

      } else if (hit_data.tri.page >= 0) {

        // If lightmapped triangle (not just an occluder).
        vec2 uv0 = hit_data.vert0.uv;
        vec2 uv1 = hit_data.vert1.uv;
        vec2 uv2 = hit_data.vert2.uv;
        vec3 uvw = vec3(hit_data.barycentric.x * uv0 + hit_data.barycentric.y * uv1 + hit_data.barycentric.z * uv2, float(hit_data.tri.page));

        // Get reflectivity at the luxel we hit.
        light = textureLod(luxel_reflectivity, uvw, 0.0).rgb;

      } else if (hit_data.tri.page < -1) {
        // Vertex-lit triangle.  Grab reflectivity of 3 triangle vertices
        // and interpolate with barycentric coordinates.
        ivec2 coords;

        coords.y = int((hit_data.tri.indices.x - u_vtx_lit_info.x) / u_vtx_lit_info.y);
        coords.x = int((hit_data.tri.indices.x - u_vtx_lit_info.x) % u_vtx_lit_info.y);
        vec3 refl0 = texelFetch(vtx_reflectivity, coords, 0).rgb;

        coords.y = int((hit_data.tri.indices.y - u_vtx_lit_info.x) / u_vtx_lit_info.y);
        coords.x = int((hit_data.tri.indices.y - u_vtx_lit_info.x) % u_vtx_lit_info.y);
        vec3 refl1 = texelFetch(vtx_reflectivity, coords, 0).rgb;

        coords.y = int((hit_data.tri.indices.z - u_vtx_lit_info.x) / u_vtx_lit_info.y);
        coords.x = int((hit_data.tri.indices.z - u_vtx_lit_info.x) % u_vtx_lit_info.y);
        vec3 refl2 = texelFetch(vtx_reflectivity, coords, 0).rgb;

        light = refl0 * hit_data.barycentric.x + refl1 * hit_data.barycentric.y + refl2 * hit_data.barycentric.z;
      }
    }

    gathered += light;

    float c[4] = float[](
      0.282095, //l0
      0.488603 * ray_dir.y, //l1n1
      0.488603 * ray_dir.z, //l1n0
      0.488603 * ray_dir.x //l1p1
    );
    for (uint j = 0; j < 4; ++j) {
      sh_accum[j].rgb += light * c[j];
    }
  }

  // Store gathered light.
  vec4 running_total = imageLoad(luxel_gathered, palette_coord);
  gathered += running_total.rgb;
  total_dot += running_total.a;
  for (uint j = 0; j < 4; ++j) {
    sh_accum[j].rgb += imageLoad(luxel_sh_gathered, ivec3(palette_pos, u_palette_page * 4 + j)).rgb;
  }
  if (u_ray_to == u_ray_count) {
    // If this is the final ray pass for this bounce, modulate the total
    // light gathered by my surface's albedo, for rays in the next bounce.
    gathered /= total_dot;

    float gathered_luminance = max(gathered.r, max(gathered.g, gathered.b));
    imageAtomicMax(feedback_total_add, 0, uint(gathered_luminance * 10000));

    vec3 surf_reflectivity = min(texelFetch(luxel_albedo, palette_coord, 0).rgb, vec3(0.99));

    // Accumulate what we gathered onto total incoming light to this luxel.
    for (int i = 0; i < 4; ++i) {
      vec3 curr_light_total;
      curr_light_total = imageLoad(luxel_light, ivec3(palette_pos, u_palette_page * 4 + i)).rgb;
      sh_accum[i].rgb /= total_dot;
      imageStore(luxel_light, ivec3(palette_pos, u_palette_page * 4 + i), vec4(curr_light_total + sh_accum[i].rgb, 1.0));
    }

    imageStore(luxel_gathered, palette_coord, vec4(gathered * surf_reflectivity, 1.0));

  } else {
    // Bounce accumulation.
    imageStore(luxel_gathered, palette_coord, vec4(gathered, total_dot));
    for (uint j = 0; j < 4; ++j) {
      imageStore(luxel_sh_gathered, ivec3(palette_pos, u_palette_page * 4 + j), vec4(sh_accum[j].rgb, 1.0));
    }
  }
}
