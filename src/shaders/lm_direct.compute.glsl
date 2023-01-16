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

// Compute shader for computing direct light into lightmaps.
// Outputs direct lighting that hits a luxel as well as the light that
// should reflect off the surface during the indirect pass.

#define TRACE_MODE_DIRECT 1

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f) uniform writeonly image2DArray luxel_direct;
layout(rgba32f) uniform writeonly image2DArray luxel_direct_dynamic;
layout(rgba32f) uniform writeonly image2DArray luxel_reflectivity;
uniform sampler2DArray luxel_albedo;
uniform sampler2DArray luxel_position;
uniform sampler2DArray luxel_normal;
uniform sampler2DArray luxel_emission;

uniform ivec3 u_palette_size_page;
#define u_palette_size (u_palette_size_page.xy)
#define u_palette_page (u_palette_size_page.z)
uniform ivec2 u_region_ofs;
uniform vec2 u_bias_sun_extent;
#define u_bias (u_bias_sun_extent.x)
#define u_sun_extent (u_bias_sun_extent.y)

const int SUN_AREA_LIGHT_SAMPLES = 30;
// These values are needed to get the same results as VRAD for sun soft
// shadows.
const float COORD_EXTENT = 2 * 16384;
const float MAX_TRACE_LENGTH = 1.732050807569 * COORD_EXTENT;

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

  LightmapTri tri;
  HitData hit_data;

  int start_node_index;
  get_kd_leaf_from_point(position + normal * u_bias, start_node_index);

  uint light_count = uint(get_num_lightmap_lights());
  for (uint i = 0; i < light_count; i++) {
    LightmapLight light = get_lightmap_light(i);

    vec3 L;
    float attenuation;
    vec3 light_pos;

    if (light.light_type == LIGHT_TYPE_DIRECTIONAL) {
      attenuation = 1.0;
      L = normalize(-light.dir);
      light_pos = position + L * 99999999;

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
    //attenuation *= NdotL;

    //if (attenuation == 0.0) {
    //  continue;
    //}

    //if (attenuation <= 0.00001) {
    //  continue;
    //}

    vec3 bary;

    uint ret = ray_cast(position + (normal * u_bias), light_pos, u_bias, luxel_albedo, start_node_index, hit_data);

    if (light.light_type == LIGHT_TYPE_DIRECTIONAL) {
      //get_lightmap_tri(hit_data.triangle, tri);

      if ((ret != RAY_MISS) && ((hit_data.tri.flags & TRIFLAGS_SKY) != 0)) {
        // Hit sky, sun light is visible.
        ret = RAY_MISS;

      } else {
        // If ray hit nothing or hit a non-sky triangle, sky is not visible.
        ret = RAY_FRONT;
      }
    }

    vec3 contrib = light.color.rgb * attenuation * PI;

    /*if (light.light_type == LIGHT_TYPE_DIRECTIONAL) {
      // Special case for sun light to implement soft shadows.
      int num_samples = 1;
      if (u_sun_extent > 0.0) {
        num_samples = SUN_AREA_LIGHT_SAMPLES;
      }

      float hash = quick_hash(light.dir.xy);

      float fraction_visible = 0.0;
      for (int d = 0; d < num_samples; d++) {
        vec3 end = light_pos;
        if (d > 0) {
          // Jitter light source location.
          vec3 ofs = vogel_hemisphere(uint(d), uint(num_samples), hash);
          ofs *= MAX_TRACE_LENGTH * u_sun_extent;
          end += ofs;
        }
        if (trace_ray(start, end, hit_dist, bary) == RAY_MISS) {
          fraction_visible += 1.0;
        }
      }
      fraction_visible /= num_samples;

      static_light += fraction_visible * attenuation * light.color.rgb;

    } else*/ if (ret == RAY_MISS) {
      if (light.bake_direct == 1) {
        static_light += contrib * NdotL;

        float c[4] = float[](
          0.282095, //l0
          -0.488603 * L.y, //l1n1
          0.488603 * L.z, //l1n0
          -0.488603 * L.x //l1p1
        );

        for (uint j = 0; j < 4; ++j) {
          sh_accum[j].rgb += contrib * c[j];
        }

      } else {
        dynamic_light += contrib * NdotL;
      }
    }
  }

#if 1
  imageStore(luxel_direct, ivec3(palette_pos, u_palette_page * 4), sh_accum[0]);
  imageStore(luxel_direct, ivec3(palette_pos, u_palette_page * 4 + 1), sh_accum[1]);
  imageStore(luxel_direct, ivec3(palette_pos, u_palette_page * 4 + 2), sh_accum[2]);
  imageStore(luxel_direct, ivec3(palette_pos, u_palette_page * 4 + 3), sh_accum[3]);
#else
  imageStore(luxel_direct, ivec3(palette_pos, u_palette_page * 4), vec4(static_light, 1.0));
#endif
  //

  imageStore(luxel_direct_dynamic, palette_coord, vec4(dynamic_light, 1.0));

  // Reflectivity = ((static light + dynamic light) * albedo) + emission
  imageStore(luxel_reflectivity, palette_coord, vec4((dynamic_light + static_light) * albedo + emission, 1.0));
}
