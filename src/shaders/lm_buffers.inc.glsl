/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_buffers.inc.glsl
 * @author lachbr
 * @date 2021-09-22
 */

// This file defines the various structures used by the lightmapper stored in
// buffer textures, and provides an interface to unpack elements.

#ifndef LM_BUFFERS_INC_GLSL
#define LM_BUFFERS_INC_GLSL

struct LightmapVertex {
  vec3 position;
  vec3 normal;
  vec2 uv;
};
uniform samplerBuffer vertices;

/**
 * Unpacks the ith lightmap vertex from the vertex buffer.
 */
LightmapVertex get_lightmap_vertex(uint i) {
  int start = int(i) * 3;
  LightmapVertex v;
  v.position = texelFetch(vertices, start).xyz;
  v.normal = texelFetch(vertices, start + 1).xyz;
  v.uv = texelFetch(vertices, start + 2).xy;
  return v;
}

void
get_lightmap_vertex(uint i, out LightmapVertex v) {
  int start = int(i) * 3;
  v.position = texelFetch(vertices, start).xyz;
  v.normal = texelFetch(vertices, start + 1).xyz;
  v.uv = texelFetch(vertices, start + 2).xy;
}

/**
 * Returns the number of lightmap vertices stored in the buffer.
 */
int get_num_lightmap_vertices() {
  return textureSize(vertices) / 3;
}

struct LightmapTri {
  uvec3 indices;
  vec3 mins;
  vec3 maxs;
  uint page;
};
uniform samplerBuffer triangles;

/**
 * Unpacks the ith lightmap triangle from the buffer.
 */
LightmapTri
get_lightmap_tri(uint i) {
  LightmapTri tri;
  int start = int(i) * 3;
  vec4 indices_page = texelFetch(triangles, start);
  tri.indices.x = uint(indices_page.x);
  tri.indices.y = uint(indices_page.y);
  tri.indices.z = uint(indices_page.z);
  tri.page = uint(indices_page.w);
  tri.mins = texelFetch(triangles, start + 1).xyz;
  tri.maxs = texelFetch(triangles, start + 2).xyz;
  return tri;
}

void
get_lightmap_tri(uint i, out LightmapTri tri) {
  int start = int(i) * 3;
  vec4 indices_page = texelFetch(triangles, start);
  tri.indices.x = uint(indices_page.x);
  tri.indices.y = uint(indices_page.y);
  tri.indices.z = uint(indices_page.z);
  tri.page = uint(indices_page.w);
  tri.mins = texelFetch(triangles, start + 1).xyz;
  tri.maxs = texelFetch(triangles, start + 2).xyz;
}

/**
 * Returns the number of lightmap triangles stored in the buffer.
 */
int
get_num_lightmap_tris() {
  return textureSize(triangles) / 3;
}

#define LIGHT_TYPE_DIRECTIONAL 0
#define LIGHT_TYPE_POINT 1
#define LIGHT_TYPE_SPOT 2

struct LightmapLight {
  vec3 color;
  uint light_type;
  vec3 pos;
  vec3 dir;
  float constant;
  float linear;
  float quadratic;

  // Spot params.
  float stopdot;
  float stopdot2;
  float oodot;
  float exponent;

  // If true, direct lighting along with indirect is baked.
  // Otherwise, only indirect is baked and direct lighting should be
  // computed at run-time.
  uint bake_direct;
};
uniform samplerBuffer lights;

/**
 * Unpacks the ith lightmap light from the buffer.
 */
LightmapLight
get_lightmap_light(uint i) {
  LightmapLight light;

  int start = int(i) * 5;

  vec4 type_atten = texelFetch(lights, start);
  light.light_type = uint(type_atten.x);
  light.constant = type_atten.y;
  light.linear = type_atten.z;
  light.quadratic = type_atten.w;

  vec4 color_bake_direct = texelFetch(lights, start + 1);
  light.color = color_bake_direct.xyz;
  light.bake_direct = uint(color_bake_direct.w);

  light.pos = texelFetch(lights, start + 2).xyz;

  light.dir = texelFetch(lights, start + 3).xyz;

  vec4 spot_params = texelFetch(lights, start + 4);
  light.exponent = spot_params.x;
  light.stopdot = spot_params.y;
  light.stopdot2 = spot_params.z;
  light.oodot = spot_params.w;

  return light;
}

/**
 * Returns the number of lightmap lights stored in the buffer.
 */
int
get_num_lightmap_lights() {
  return textureSize(lights) / 5;
}

uniform usamplerBuffer triangle_cells;
/**
 *
 */
uint
get_tri_for_cell(int i) {
  return texelFetch(triangle_cells, i).x;
}

uniform usampler3D grid;

#endif // LM_BUFFERS_INC_GLSL
