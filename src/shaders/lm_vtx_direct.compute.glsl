#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_vtx_direct.compute.glsl
 * @author brian
 * @date 2022-06-07
 */

#define TRACE_MODE_DIRECT 1
#define TRACE_IGNORE_BACKFACE 1

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_compute.inc.glsl"

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(rgba32f) uniform writeonly image2D vtx_reflectivity;
layout(rgba32f) uniform writeonly image2D vtx_light;
layout(rgba32f) uniform writeonly image2D vtx_light_dynamic;
uniform sampler2D vtx_albedo;
uniform sampler2DArray luxel_albedo;

uniform ivec4 u_vtx_palette_size_first_vtx_num_verts;
#define u_vtx_palette_size (u_vtx_palette_size_first_vtx_num_verts.xy)
#define u_first_vtx (u_vtx_palette_size_first_vtx_num_verts.z)
#define u_num_verts (u_vtx_palette_size_first_vtx_num_verts.w)
uniform vec2 _u_bias;
#define u_bias (_u_bias.x)

const float COORD_EXTENT = 2 * 16384;
const float MAX_TRACE_LENGTH = 1.732050807569 * COORD_EXTENT;

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
  vec3 albedo = texelFetch(vtx_albedo, palette_pos, 0).rgb;

  vec3 direct_light = vec3(0.0);
  vec3 dynamic_light = vec3(0.0);

  HitData hit_data;

  int start_node_index;
  get_kd_leaf_from_point(position + normal * u_bias, start_node_index);

  uint light_count = uint(get_num_lightmap_lights());
  for (uint i = 0; i < light_count; ++i) {
    LightmapLight light = get_lightmap_light(i);

    vec3 L;
    float attenuation;
    vec3 light_pos;

    if (light.light_type == LIGHT_TYPE_DIRECTIONAL) {
      attenuation = 1.0;
      L = normalize(-light.dir);
      light_pos = position - light.dir * MAX_TRACE_LENGTH;

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

    vec3 bary;

    uint ret = ray_cast(position + normal * u_bias, light_pos, u_bias, luxel_albedo,
                        start_node_index, hit_data);
    if (light.light_type == LIGHT_TYPE_DIRECTIONAL) {
      if ((ret != RAY_MISS) && ((hit_data.tri.flags & TRIFLAGS_SKY) != 0)) {
        // Hit sky, sun light is visible.
        ret = RAY_MISS;
      } else {
        ret = RAY_FRONT;
      }
    }

    if (ret == RAY_MISS) {
      if (light.bake_direct == 1) {
        direct_light += attenuation * light.color.rgb * PI;
      } else {
        dynamic_light += attenuation * light.color.rgb * PI;
      }
    }
  }

  imageStore(vtx_light, palette_pos, vec4(direct_light / PI, 1.0));

  imageStore(vtx_light_dynamic, palette_pos, vec4(dynamic_light * albedo, 1.0));

  // Reflectivity = (static light + dynamic light) * albedo
  imageStore(vtx_reflectivity, palette_pos, vec4((direct_light + dynamic_light) * albedo, 1.0));
}
