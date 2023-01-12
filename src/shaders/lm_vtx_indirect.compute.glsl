#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_vtx_indirect.compute.glsl
 * @author brian
 * @date 2022-06-08
 */

// Compute shader for gathering indirect lighting for a vertex.

#define TRACE_MODE_INDIRECT 1
#define TRACE_IGNORE_BACKFACE 1

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Luxel reflectivity.  On bounce 0, contains direct light * albedo + emission.
// Subsequent bounces contain gathered light from previous bounce.
uniform sampler2DArray luxel_reflectivity;
uniform sampler2DArray luxel_albedo;

// Also reflect light off of vertex-lit geometry.
uniform sampler2D vtx_reflectivity;
uniform sampler2D vtx_albedo;
layout(rgba32f) uniform image2D vtx_gathered;
layout(rgba32f) uniform image2D vtx_light;

// This stores the total amount of light we added on this bounce.
// This is read back on the CPU to determine when the lighting has
// stabilized.
layout(r32ui) uniform uimage1D feedback_total_add;

uniform ivec4 u_vtx_palette_size_first_vtx_num_verts;
#define u_vtx_palette_size (u_vtx_palette_size_first_vtx_num_verts.xy)
#define u_first_vtx (u_vtx_palette_size_first_vtx_num_verts.z)
#define u_num_verts (u_vtx_palette_size_first_vtx_num_verts.w)
uniform ivec4 u_ray_count_bounce;
#define u_ray_start (u_ray_count_bounce.x)
#define u_ray_end (u_ray_count_bounce.y)
#define u_ray_count (u_ray_count_bounce.z)
#define u_bounce (u_ray_count_bounce.w)
uniform vec2 _u_bias;
#define u_bias (_u_bias.x)
uniform ivec2 u_region_ofs;

uniform vec3 u_sky_color;

void
main() {
  ivec2 palette_pos = ivec2(gl_GlobalInvocationID.xy) + u_region_ofs;
  if (any(greaterThanEqual(palette_pos, u_vtx_palette_size))) {
    return;
  }

  int vtx_index = palette_pos.y * u_vtx_palette_size.x;
  vtx_index += palette_pos.x;

  if (vtx_index >= u_num_verts) {
    return;
  }

  LightmapVertex this_vert;
  get_lightmap_vertex(vtx_index + u_first_vtx, this_vert);

  vec3 position = this_vert.position;
  vec3 normal = normalize(this_vert.normal);

  vec3 x;
  bool is_z = false;
  if (abs(normal.x) >= abs(normal.y) && abs(normal.x) >= abs(normal.z)) {

  } else if (abs(normal.y) >= abs(normal.z)) {

  } else {
    is_z = true;
  }

  vec3 v0 = is_z ? vec3(1, 0, 0) : vec3(0, 0, 1);
  vec3 tangent = normalize(cross(v0, normal));
  vec3 bitangent = normalize(cross(tangent, normal));
  mat3 normal_mat = mat3(tangent, bitangent, normal);

  HitData hit_data;

  int start_node_index;
  get_kd_leaf_from_point(position + normal * u_bias, start_node_index);

  vec3 gathered = vec3(0);
  float total_dot = 0.0;
  uint noise = random_seed(ivec3(u_ray_start, palette_pos));
  for (uint i = uint(u_ray_start); i < uint(u_ray_end); i++) {
    vec3 ray_dir = normal_mat * generate_hemisphere_cosine_weighted_direction(noise);
    ray_dir = normalize(ray_dir);

    float dt = dot(normal, ray_dir);
    if (dt <= 0.0) {
      continue;
    }

    total_dot += dt;

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

        coords.y = int((hit_data.tri.indices.x - u_first_vtx) / u_vtx_palette_size.x);
        coords.x = int((hit_data.tri.indices.x - u_first_vtx) % u_vtx_palette_size.x);
        vec3 refl0 = texelFetch(vtx_reflectivity, coords, 0).rgb;

        coords.y = int((hit_data.tri.indices.y - u_first_vtx) / u_vtx_palette_size.x);
        coords.x = int((hit_data.tri.indices.y - u_first_vtx) % u_vtx_palette_size.x);
        vec3 refl1 = texelFetch(vtx_reflectivity, coords, 0).rgb;

        coords.y = int((hit_data.tri.indices.z - u_first_vtx) / u_vtx_palette_size.x);
        coords.x = int((hit_data.tri.indices.z - u_first_vtx) % u_vtx_palette_size.x);
        vec3 refl2 = texelFetch(vtx_reflectivity, coords, 0).rgb;

        light = refl0 * hit_data.barycentric.x + refl1 * hit_data.barycentric.y + refl2 * hit_data.barycentric.z;
      }
    }

    gathered += light;
  }

  vec4 running_total = imageLoad(vtx_gathered, palette_pos);
  gathered += running_total.rgb;
  total_dot += running_total.a;

  if (u_ray_end == u_ray_count) {
    gathered /= total_dot;

    vec3 surf_reflectivity = min(texelFetch(vtx_albedo, palette_pos, 0).rgb, vec3(0.99));
    imageStore(vtx_gathered, palette_pos, vec4(gathered * surf_reflectivity, 1.0));

    // Accumulate what we gathered onto total incoming light to this vertex.
    vec4 total_light = imageLoad(vtx_light, palette_pos);
    total_light.rgb += gathered;
    imageStore(vtx_light, palette_pos, total_light);

    float gathered_luminance = max(gathered.r, max(gathered.g, gathered.b));
    imageAtomicMax(feedback_total_add, 0, uint(gathered_luminance * 10000));
  } else {
    imageStore(vtx_gathered, palette_pos, vec4(gathered, total_dot));
  }
}
