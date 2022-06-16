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
 * @author lachbr
 * @date 2022-06-08
 */

// Compute shader for gathering indirect lighting for a vertex.

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Luxel reflectivity.  On bounce 0, contains direct light * albedo + emission.
// Subsequent bounces contain gathered light from previous bounce.
uniform sampler2DArray luxel_reflectivity;
uniform sampler2DArray luxel_albedo;

// Also reflect light off of vertex-lit geometry.
uniform sampler2D vtx_reflectivity;
layout(rgba32f) uniform writeonly image2D vtx_gathered;

uniform ivec4 u_vtx_palette_size_first_vtx_num_verts;
#define u_vtx_palette_size (u_vtx_palette_size_first_vtx_num_verts.xy)
#define u_first_vtx (u_vtx_palette_size_first_vtx_num_verts.z)
#define u_num_verts (u_vtx_palette_size_first_vtx_num_verts.w)
uniform ivec2 u_ray_count_bounce;
#define u_ray_count (u_ray_count_bounce.x)
#define u_bounce (u_ray_count_bounce.y)
uniform vec2 _u_bias;
#define u_bias (_u_bias.x)

uniform vec3 u_sky_color;

void
main() {
  ivec2 palette_pos = ivec2(gl_GlobalInvocationID.xy);
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

  LightmapTri tri;
  LightmapVertex vert0, vert1, vert2;

  vec3 gathered = vec3(0);
  float active_rays = 0.0;
  uint noise = random_seed(ivec3(0, palette_pos));
  for (uint i = 0; i < uint(u_ray_count); i++) {
    vec3 ray_dir = normal_mat * generate_hemisphere_cosine_weighted_direction(noise);

    vec3 barycentric;

    vec3 light = vec3(0);
    uint trace_result = ray_cast(position + normal * u_bias,
                                 position + ray_dir * 9999999,
                                 u_bias,
                                 barycentric, tri, vert0, vert1, vert2,
                                 luxel_albedo, false);

    if (trace_result == RAY_FRONT) {
      // Hit a triangle.

      if ((tri.flags & TRIFLAGS_SKY) != 0) {
        // Hit sky.  Bring in sky ambient color, but only on the first bounce.
        if (u_bounce == 0) {
          light = u_sky_color;
        }
        active_rays += 1.0;

      } else if (tri.page >= 0) {
        // If lightmapped triangle (not just an occluder).
        vec2 uv0 = vert0.uv;
        vec2 uv1 = vert1.uv;
        vec2 uv2 = vert2.uv;
        vec3 uvw = vec3(barycentric.x * uv0 + barycentric.y * uv1 + barycentric.z * uv2, float(tri.page));

        // Get reflectivity at the luxel we hit.
        light = textureLod(luxel_reflectivity, uvw, 0.0).rgb;
        active_rays += 1.0;

      } else if (tri.page < -1) {
        // Vertex-lit triangle.  Grab reflectivity of 3 triangle vertices
        // and interpolate with barycentric coordinates.
        ivec2 coords;

        coords.y = int((tri.indices.x - u_first_vtx) / u_vtx_palette_size.x);
        coords.x = int((tri.indices.x - u_first_vtx) % u_vtx_palette_size.x);
        vec3 refl0 = texelFetch(vtx_reflectivity, coords, 0).rgb;

        coords.y = int((tri.indices.y - u_first_vtx) / u_vtx_palette_size.x);
        coords.x = int((tri.indices.y - u_first_vtx) % u_vtx_palette_size.x);
        vec3 refl1 = texelFetch(vtx_reflectivity, coords, 0).rgb;

        coords.y = int((tri.indices.z - u_first_vtx) / u_vtx_palette_size.x);
        coords.x = int((tri.indices.z - u_first_vtx) % u_vtx_palette_size.x);
        vec3 refl2 = texelFetch(vtx_reflectivity, coords, 0).rgb;

        light = refl0 * barycentric.x + refl1 * barycentric.y + refl2 * barycentric.z;
        active_rays += 1.0;
      }
    }

    gathered += light;
  }

  if (active_rays > 0) {
    gathered /= active_rays;
  }

  // Store light gathered from this bounce, will be reflected in next bounce.
  imageStore(vtx_gathered, palette_pos, vec4(gathered, 1.0));
}
