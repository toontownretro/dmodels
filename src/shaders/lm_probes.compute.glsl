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

#define TRACE_MODE_PROBES 1

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Probe positions.
uniform samplerBuffer probes;
// Output probe data.
layout(rgba32f) uniform imageBuffer probe_output;
//layout(rgba32f) uniform imageBuffer probe_flat_output;

uniform sampler2DArray luxel_light;
uniform sampler2DArray luxel_light_dynamic;
uniform sampler2DArray luxel_albedo;

uniform ivec2 _u_probe_count;
#define u_probe_count (_u_probe_count.x)

uniform vec2 u_bias_;
#define u_bias (u_bias_.x)

uniform ivec3 u_ray_params;
#define u_ray_from (u_ray_params.x)
#define u_ray_to (u_ray_params.y)
#define u_ray_count (u_ray_params.z)

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

  vec4 flat_accum = vec4(0.0);

  float active_rays = 0.0;

  LightmapTri tri;
  LightmapVertex vert0, vert1, vert2;

#if 1
  uint noise = random_seed(ivec3(0, probe_index, 49502741));
  for (uint i = 0; i < u_ray_count; i++) {
    vec3 ray_dir = generate_hemisphere_uniform_direction(noise);
    if (bool(i & 1)) {
      // Throw to both sides, so alternate them.
      ray_dir.z *= -1.0;
    }

    vec3 barycentric;
    vec3 light = vec3(0.0);

    uint trace_result = ray_cast(position + ray_dir * u_bias, position + ray_dir * 9999999,
                                 u_bias, barycentric, tri, vert0, vert1, vert2, luxel_albedo, true);
    if (trace_result == RAY_FRONT) {
      if ((tri.flags & TRIFLAGS_SKY) != 0) {
        // Hit sky.  Bring in sky ambient color.
        light = u_sky_color;
        active_rays += 1.0;

      } else if (tri.page >= 0) {
        vec2 uv0 = vert0.uv;
        vec2 uv1 = vert1.uv;
        vec2 uv2 = vert2.uv;
        vec3 uvw = vec3(barycentric.x * uv0 + barycentric.y * uv1 + barycentric.z * uv2, float(tri.page));

        light = textureLod(luxel_light, uvw, 0.0).rgb;
        light += textureLod(luxel_light_dynamic, uvw, 0.0).rgb;
        //light = vec3(1);
      }

      active_rays += 1.0;
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

    {
      flat_accum.rgb += light;
    }
  }
#endif

  //if (u_ray_from > 0) {
  //  for (uint j = 0; j < 9; j++) {
  //    probe_sh_accum[j] += imageLoad(probe_output, int(probe_index * 9 + j));
  //  }
  //}

  //if (u_ray_to >= u_ray_count) {
    for (uint j = 0; j < 9; j++) {
      probe_sh_accum[j] *= 4.0 / active_rays;
    }
  //}

  for (uint j = 0; j < 9; j++) {
    imageStore(probe_output, int(probe_index * 9 + j), probe_sh_accum[j]);
  }

  //imageStore(probe_flat_output, probe_index, flat_accum);
}
