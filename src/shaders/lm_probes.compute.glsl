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
 * @author brian
 * @date 2021-09-23
 */

// Shader for computing ambient light probes.

#define TRACE_MODE_PROBES 1

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Probe positions.
uniform samplerBuffer probes;
// Output probe data.
layout(rgba32f) uniform imageBuffer probe_output;

uniform sampler2DArray luxel_reflectivity;
uniform sampler2DArray luxel_albedo;

uniform sampler2D vtx_reflectivity;
// X: LightmapVertex index of first vertex-lit vertex.
// Y: Width of the vertex palette.
uniform uvec2 u_vtx_lit_info;

uniform ivec2 _u_probe_count;
#define u_probe_count (_u_probe_count.x)

uniform vec2 u_bias_;
#define u_bias (u_bias_.x)

uniform ivec4 u_ray_params;
#define u_ray_from (u_ray_params.x)
#define u_ray_to (u_ray_params.y)
#define u_ray_count (u_ray_params.z)
#define u_bounce (u_ray_params.w)

uniform vec3 u_sky_color;

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

  HitData hit_data;

  int start_node_index;
  get_kd_leaf_from_point(position, start_node_index);

  uint noise = random_seed(ivec3(0, probe_index, 49502741));
  float ray_weight = (4.0 * PI) / float(u_ray_count);
  for (uint i = uint(u_ray_from); i < uint(u_ray_to); i++) {
    vec3 ray_dir = generate_hemisphere_uniform_direction(noise);
    if (bool(i & 1)) {
      // Throw to both sides, so alternate them.
      ray_dir.z *= -1.0;
    }

    ray_dir = normalize(ray_dir);

    vec3 light = vec3(0.0);

    uint trace_result = ray_cast(position, position + ray_dir * 9999999,
                                 u_bias, luxel_albedo,
                                 start_node_index, hit_data);
    if (trace_result == RAY_FRONT) {

      if ((hit_data.tri.flags & TRIFLAGS_SKY) != 0) {
        // Hit sky.  Bring in sky ambient color.
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

    {
      // Accumulate into L2 spherical harmonics.
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
        probe_sh_accum[j].rgb += light * c[j] * ray_weight;
      }
    }
  }

  if (u_bounce > 0 || u_ray_from > 0) {
    for (uint j = 0; j < 9; ++j) {
      probe_sh_accum[j].rgb += imageLoad(probe_output, int(probe_index * 9 + j)).rgb;
    }
  }

  for (uint j = 0; j < 9; j++) {
    imageStore(probe_output, int(probe_index * 9 + j), probe_sh_accum[j]);
  }
}
