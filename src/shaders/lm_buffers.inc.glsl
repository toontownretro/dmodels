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
  vec4 indices_page = texelFetch(triangles, start);
  tri.indices.x = uint(indices_page.x);
  tri.indices.y = uint(indices_page.y);
  tri.indices.z = uint(indices_page.z);
  tri.page = int(indices_page.w);
  vec4 mins_flags = texelFetch(triangles, start + 1);
  tri.mins = mins_flags.xyz;
  tri.flags = uint(mins_flags.w);
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
  tri.page = int(indices_page.w);

  vec4 mins_flags = texelFetch(triangles, start + 1);
  tri.mins = mins_flags.xyz;
  tri.flags = uint(mins_flags.w);

  tri.maxs = texelFetch(triangles, start + 2).xyz;
}

void
get_lightmap_tri_0(uint i, inout LightmapTri tri) {
  int start = int(i) * 3;

  vec4 mins_flags = texelFetch(triangles, start + 1);
  tri.mins = mins_flags.xyz;
  tri.flags = uint(mins_flags.w);

  tri.maxs = texelFetch(triangles, start + 2).xyz;
}

void
get_lightmap_tri_1(uint i, inout LightmapTri tri) {
  int start = int(i) * 3;
  vec4 indices_page = texelFetch(triangles, start);
  tri.indices.x = uint(indices_page.x);
  tri.indices.y = uint(indices_page.y);
  tri.indices.z = uint(indices_page.z);
  tri.page = int(indices_page.w);
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

#define NEIGHBOR_LEFT 0
#define NEIGHBOR_RIGHT 1
#define NEIGHBOR_BACK 2
#define NEIGHBOR_FRONT 3
#define NEIGHBOR_BOTTOM 4
#define NEIGHBOR_TOP 5

struct KDNode {
  int back_child;
  int front_child;

  int axis;
  float dist;

  vec3 mins;
  vec3 maxs;

  int leaf_num;
};
uniform samplerBuffer kd_nodes;

struct KDLeaf {
  int neighbors[6];
  uint first_triangle;
  uint num_triangles;
};
uniform samplerBuffer kd_leaves;

int
get_num_kd_nodes() {
  return textureSize(kd_nodes) / 3;
}

int get_num_kd_leaves() {
  return textureSize(kd_leaves) / 2;
}

void
get_kd_leaf(int index, out KDLeaf leaf) {
  int start = int(index) * 2;

  vec4 data = texelFetch(kd_leaves, start);
  leaf.neighbors[0] = int(data.x);
  leaf.neighbors[1] = int(data.y);
  leaf.neighbors[2] = int(data.z);
  leaf.neighbors[3] = int(data.w);

  data = texelFetch(kd_leaves, start + 1);
  leaf.neighbors[4] = int(data.x);
  leaf.neighbors[5] = int(data.y);
  leaf.first_triangle = uint(data.z);
  leaf.num_triangles = uint(data.w);
}

void
get_kd_node(int index, out KDNode node) {
  int start = index * 3;

  vec4 children_axis_dist = texelFetch(kd_nodes, start);
  node.back_child = int(children_axis_dist.x);
  node.front_child = int(children_axis_dist.y);
  node.axis = int(children_axis_dist.z);
  node.dist = children_axis_dist.w;

  vec4 mins_leaf_num = texelFetch(kd_nodes, start + 1);
  node.mins = mins_leaf_num.xyz;
  node.leaf_num = int(mins_leaf_num.w);

  node.maxs = texelFetch(kd_nodes, start + 2).xyz;
}

void
get_kd_node_0(int index, inout KDNode node) {
  int start = index * 3;
  vec4 children_axis_dist = texelFetch(kd_nodes, start);
  node.back_child = int(children_axis_dist.x);
  node.front_child = int(children_axis_dist.y);
  node.axis = int(children_axis_dist.z);
  node.dist = children_axis_dist.w;
}

void
get_kd_node_1(int index, inout KDNode node) {
  int start = index * 3;
  vec4 mins_leaf_num = texelFetch(kd_nodes, start + 1);
  node.mins = mins_leaf_num.xyz;
  node.leaf_num = int(mins_leaf_num.w);
  node.maxs = texelFetch(kd_nodes, start + 2).xyz;
}

int
get_kd_neighbor(in KDNode node, in KDLeaf leaf, in vec3 point) {
  if (abs(point.y - node.maxs.y) < 0.0001) {
    return leaf.neighbors[NEIGHBOR_FRONT];

  } else if (abs(point.y - node.mins.y) < 0.0001) {
    return leaf.neighbors[NEIGHBOR_BACK];

  } else if (abs(point.x - node.mins.x) < 0.0001) {
    return leaf.neighbors[NEIGHBOR_LEFT];

  } else if (abs(point.x - node.maxs.x) < 0.0001) {
    return leaf.neighbors[NEIGHBOR_RIGHT];

  } else if (abs(point.z - node.mins.z) < 0.0001) {
    return leaf.neighbors[NEIGHBOR_BOTTOM];

  } else if (abs(point.z - node.maxs.z) < 0.0001) {
    return leaf.neighbors[NEIGHBOR_TOP];

  } else {
    // BAD!
    return -1;
  }
}

uniform usamplerBuffer kd_triangles;

uint get_num_kd_tris() {
  return textureSize(kd_triangles);
}

uint get_kd_tri(uint index) {
  return texelFetch(kd_triangles, int(index)).x;
}

#endif // LM_BUFFERS_INC_GLSL
