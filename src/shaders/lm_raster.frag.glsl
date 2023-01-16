#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_raster.frag.glsl
 * @author brian
 * @date 2021-09-21
 */

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_buffers.inc.glsl"

uniform sampler2D base_texture_sampler;
uniform vec3 emission_color;
uniform ivec3 first_triangle_transparency_emission;
uniform vec2 geom_uv_mins;
uniform vec2 geom_uv_maxs;
#define has_transparency (bool(first_triangle_transparency_emission.y))
#define has_emission (bool(first_triangle_transparency_emission.z))

in vec2 l_texcoord;
in vec2 l_texcoord_lightmap;
in vec3 l_barycentric;
in vec3 l_world_position;
in vec3 l_world_normal;
in vec4 l_color;
in flat uvec3 vertex_indices;
in flat vec3 face_normal;

layout(location = 0) out vec4 albedo_output;
layout(location = 1) out vec4 position_output;
layout(location = 2) out vec4 normal_output;
layout(location = 3) out vec4 unocclude_output;
layout(location = 4) out vec4 emission_output;

void
main() {
  vec3 vertex_pos = l_world_position;

  {
    // Compute smooth vertex position using smooth normal.

    LightmapVertex v1 = get_lightmap_vertex(vertex_indices.x);
    LightmapVertex v2 = get_lightmap_vertex(vertex_indices.y);
    LightmapVertex v3 = get_lightmap_vertex(vertex_indices.z);

    vec2 uv = l_texcoord_lightmap;
    // Constrain samples to be within UV bounds of the triangle's geom's lightmap.
    if (uv.x > geom_uv_maxs.x ||
        uv.y > geom_uv_maxs.y ||
        uv.x < geom_uv_mins.x ||
        uv.y < geom_uv_mins.y) {
      discard;
    }

    vec3 pos_a = v1.position;
    vec3 pos_b = v2.position;
    vec3 pos_c = v3.position;
    vec3 center = (pos_a + pos_b + pos_c) / 3.0;
    vec3 norm_a = v1.normal;
    vec3 norm_b = v2.normal;
    vec3 norm_c = v3.normal;

    {
      vec3 dir_a = normalize(pos_a - center);
      float d_a = dot(dir_a, norm_a);
      if (d_a < 0) {
        // Pointing inwards.
        norm_a = normalize(norm_a - dir_a * d_a);
      }
    }
    {
      vec3 dir_b = normalize(pos_b - center);
      float d_b = dot(dir_b, norm_b);
      if (d_b < 0) {
        // Pointing inwards.
        norm_b = normalize(norm_b - dir_b * d_b);
      }
    }
    {
      vec3 dir_c = normalize(pos_c - center);
      float d_c = dot(dir_c, norm_c);
      if (d_c < 0) {
        // Pointing inwards.
        norm_c = normalize(norm_c - dir_c * d_c);
      }
    }

    float d_a = dot(norm_a, pos_a);
    float d_b = dot(norm_b, pos_b);
    float d_c = dot(norm_c, pos_c);

    vec3 proj_a = vertex_pos - norm_a * (dot(norm_a, vertex_pos) - d_a);
    vec3 proj_b = vertex_pos - norm_b * (dot(norm_b, vertex_pos) - d_b);
    vec3 proj_c = vertex_pos - norm_c * (dot(norm_c, vertex_pos) - d_c);

    vec3 smooth_pos = proj_a * l_barycentric.x +
                      proj_b * l_barycentric.y +
                      proj_c * l_barycentric.z;

    // Only project outwards.
    if (dot(face_normal, smooth_pos) > dot(face_normal, vertex_pos)) {
      vertex_pos = smooth_pos;
    }
  }

  {
    vec3 delta_uv = max(abs(dFdx(l_world_position)), abs(dFdy(l_world_position)));
    float texel_size = max(delta_uv.x, max(delta_uv.y, delta_uv.z));
    texel_size *= sqrt(2.0);

    unocclude_output.xyz = face_normal;
    unocclude_output.w = texel_size;
  }

  vec4 albedo = textureLod(base_texture_sampler, l_texcoord, 0);

  float alpha = 1.0;
  if (has_transparency && !has_emission) {
    alpha = albedo.a;
  }

  albedo.rgb = clamp(albedo.rgb, vec3(0.0), vec3(0.99));

  albedo_output = vec4(albedo.rgb, alpha);
  position_output = vec4(vertex_pos, alpha);
  normal_output = vec4(normalize(l_world_normal), 1.0);
  if (has_emission) {
    emission_output = vec4(albedo.rgb * emission_color * albedo.a, 1.0);
  } else {
    emission_output = vec4(0, 0, 0, 1);
  }
}
