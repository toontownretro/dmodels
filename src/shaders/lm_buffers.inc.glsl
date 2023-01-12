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
  int start = int(i) * 2;

  LightmapVertex v;

  vec4 pos_u = texelFetch(vertices, start);
  vec4 normal_v = texelFetch(vertices, start + 1);

  v.position = pos_u.xyz;

  v.normal = normal_v.xyz;

  v.uv.x = pos_u.w;
  v.uv.y = normal_v.w;

  return v;
}

void
get_lightmap_vertex(uint i, out LightmapVertex v) {
  int start = int(i) * 2;

  vec4 pos_u = texelFetch(vertices, start);
  vec4 normal_v = texelFetch(vertices, start + 1);

  v.position = pos_u.xyz;

  v.normal = normal_v.xyz;

  v.uv.x = pos_u.w;
  v.uv.y = normal_v.w;
}

void
get_lightmap_vertex_0(uint i, inout LightmapVertex v) {
  int start = int(i) * 2;
  vec4 pos_u = texelFetch(vertices, start);
  v.position = pos_u.xyz;
  v.uv.x = pos_u.w;
}

void
get_lightmap_vertex_1(uint i, inout LightmapVertex v) {
  int start = int(i) * 2;
  vec4 normal_v = texelFetch(vertices, start + 1);
  v.normal = normal_v.xyz;
  v.uv.y = normal_v.w;
}

/**
 * Returns the number of lightmap vertices stored in the buffer.
 */
int get_num_lightmap_vertices() {
  return textureSize(vertices) / 2;
}

struct LightmapTri {
  uvec3 indices;
  vec3 mins;
  vec3 maxs;
  int page;
  uint flags;
};
uniform samplerBuffer triangles;

/**
 * Unpacks the ith lightmap triangle from the buffer.
 */
LightmapTri
get_lightmap_tri(uint i) {
  LightmapTri tri;
  int start = int(i) * 3;
  vec4 indices = texelFetch(triangles, start);
  tri.indices.x = uint(indices.x);
  tri.indices.y = uint(indices.y);
  tri.indices.z = uint(indices.z);
  vec4 mins_flags = texelFetch(triangles, start + 1);
  tri.mins = mins_flags.xyz;
  tri.flags = uint(mins_flags.w);
  vec4 maxs_page = texelFetch(triangles, start + 2);
  tri.maxs = maxs_page.xyz;
  tri.page = int(maxs_page.w);
  return tri;
}

void
get_lightmap_tri(uint i, out LightmapTri tri) {
  int start = int(i) * 3;

  vec4 data = texelFetch(triangles, start);
  tri.indices.x = uint(data.x);
  tri.indices.y = uint(data.y);
  tri.indices.z = uint(data.z);

  data = texelFetch(triangles, start + 1);
  tri.mins = data.xyz;
  tri.flags = uint(data.w);

  data = texelFetch(triangles, start + 2);
  tri.maxs = data.xyz;
  tri.page = int(data.w);
}

void
get_lightmap_tri_0(uint i, inout LightmapTri tri) {
  int start = int(i) * 3;

  vec4 data = texelFetch(triangles, start + 1);

  tri.mins = data.xyz;
  tri.flags = uint(data.w);

  data = texelFetch(triangles, start + 2);
  tri.maxs = data.xyz;
  tri.page = int(data.w);
}

void
get_lightmap_tri_1(uint i, inout LightmapTri tri) {
  int start = int(i) * 3;
  vec4 data = texelFetch(triangles, start);
  tri.indices.x = uint(data.x);
  tri.indices.y = uint(data.y);
  tri.indices.z = uint(data.z);
}

void
get_tri_verts(uint v0, uint v1, uint v2, out vec3 vert0, out vec3 vert1, out vec3 vert2) {
  vert0 = texelFetch(vertices, int(v0) * 2).xyz;
  vert1 = texelFetch(vertices, int(v1) * 2).xyz;
  vert2 = texelFetch(vertices, int(v2) * 2).xyz;
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
 * Returns the number of lightmap lights stored in the buffer.
 */
uint
get_num_lightmap_lights() {
  return textureSize(lights) / 5;
}

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

#define NEIGHBOR_LEFT 1
#define NEIGHBOR_RIGHT 0
#define NEIGHBOR_BACK 3
#define NEIGHBOR_FRONT 2
#define NEIGHBOR_BOTTOM 5
#define NEIGHBOR_TOP 4

struct KDNode {
  int back_child;
  int front_child;
  int axis;
  float dist;
};
uniform samplerBuffer kd_nodes;

int
get_num_kd_nodes() {
  return textureSize(kd_nodes);
}

void
get_kd_node(int index, out KDNode node) {
  vec4 data = texelFetch(kd_nodes, index);
  node.back_child = int(data.x);
  node.front_child = int(data.y);
  node.axis = int(data.z);
  node.dist = data.w;
}

struct KDLeaf {
  vec3 mins;
  vec3 maxs;
  int neighbors[6];
  uint first_triangle;
  uint num_triangles;
};
uniform samplerBuffer kd_leaves;

void
get_kd_leaf(int leaf_index, inout KDLeaf leaf) {
  int start = leaf_index * 4;

  vec4 data = texelFetch(kd_leaves, start);
  leaf.mins = data.xyz;

  data = texelFetch(kd_leaves, start + 1);
  leaf.maxs = data.xyz;

  data = texelFetch(kd_leaves, start + 2);
  leaf.neighbors[0] = int(data.x);
  leaf.neighbors[1] = int(data.y);
  leaf.neighbors[2] = int(data.z);
  leaf.neighbors[3] = int(data.w);

  data = texelFetch(kd_leaves, start + 3);
  leaf.neighbors[4] = int(data.x);
  leaf.neighbors[5] = int(data.y);
  leaf.first_triangle = uint(data.z);
  leaf.num_triangles = uint(data.w);
}

uint
get_num_kd_leaves() {
  return textureSize(kd_leaves) / 4;
}

float
get_kd_neighbor_new(in KDLeaf leaf, in vec3 point, in vec3 invDir, out int exitSide) {
  bvec3 lt = lessThan(invDir, vec3(0.0));
  vec3 tmax = (mix(leaf.maxs, leaf.mins, lt) - point) * invDir;
  ivec3 signs = ivec3(lt);
  vec2 vals;
  vals = mix(vec2(tmax.y, NEIGHBOR_FRONT + signs.y), vec2(tmax.x, signs.x), vec2(tmax.y > tmax.x));
  vals = mix(vec2(tmax.z, NEIGHBOR_TOP + signs.z), vec2(vals.x, vals.y), vec2(tmax.z > vals.x));
  exitSide = int(vals.y);
  return vals.x;
}

uniform usamplerBuffer kd_triangles;

uint get_num_kd_tris() {
  return textureSize(kd_triangles);
}

uint get_kd_tri(uint index) {
  return texelFetch(kd_triangles, int(index)).x;
}

uniform vec3 scene_mins;
uniform vec3 scene_maxs;

#endif // LM_BUFFERS_INC_GLSL
