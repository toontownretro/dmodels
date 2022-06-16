/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_compute.inc.glsl
 * @author lachbr
 * @date 2021-09-23
 */

#include "shaders/lm_buffers.inc.glsl"

const float RAY_EPSILON = 0.00001;

#define TRIFLAGS_NONE 0
#define TRIFLAGS_SKY 1
#define TRIFLAGS_TRANSPARENT 2
#define TRIFLAGS_DONTCASTSHADOWS 4
#define TRIFLAGS_DONTRECEIVESHADOWS 8

/**
 * Returns true if the given ray intersects the given triangle.
 * Fills in intersection distance and barycentric coordinates.
 */
bool
ray_hits_triangle(vec3 from, vec3 dir, float max_dist, float bias, vec3 p0,
                  vec3 p1, vec3 p2, out float dist, out vec3 barycentric) {
  const vec3 e0 = p1 - p0;
	const vec3 e1 = p0 - p2;
	vec3 triangle_normal = cross(e1, e0);

	float n_dot_dir = dot(triangle_normal, dir);

	if (abs(n_dot_dir) < RAY_EPSILON) {
		return false;
	}

	const vec3 e2 = (p0 - from) / n_dot_dir;
	const vec3 i = cross(dir, e2);

	barycentric.y = dot(i, e1);
	barycentric.z = dot(i, e0);
	barycentric.x = 1.0 - (barycentric.z + barycentric.y);
	dist = dot(triangle_normal, e2);

	return (dist > bias) && (dist < max_dist) && all(greaterThanEqual(barycentric, vec3(0.0)));
}

#define RAY_MISS 0
#define RAY_FRONT 1
#define RAY_BACK 2
#define RAY_CROSS 3

bool ray_aabb_test(vec3 mins, vec3 maxs, vec3 origin, vec3 recip_dir, out float t_near, out float t_far) {

  vec3 t0 = (mins - origin) * recip_dir;
  vec3 t1 = (maxs - origin) * recip_dir;

  vec3 tmin = min(t0, t1);
  vec3 tmax = max(t0, t1);

  float fmin = max(tmin.x, max(tmin.y, tmin.z));
  float fmax = min(tmax.x, min(tmax.y, tmax.z));

  if (fmax < 0.0) {
    return false;
  }

  if (fmin > fmax) {
    return false;
  }

  t_near = max(0.0, fmin);
  t_far = fmax;

  return true;
}

/**
 *
 */
uint ray_cast(vec3 ray_start, vec3 ray_end, float bias, out vec3 o_bary, out LightmapTri tri,
              out LightmapVertex vert0, out LightmapVertex vert1,
              out LightmapVertex vert2, in sampler2DArray luxel_albedo_samp, bool ignore_vertex_lit) {
  KDNode curr_node;
  KDLeaf leaf;

  const float inf = 999999999.0;

  vec3 ray_vec = ray_end - ray_start;
  float ray_len = length(ray_vec);
  vec3 ray_dir = normalize(ray_vec);
  vec3 ray_recip_dir = 1.0 / ray_dir;

  get_kd_node(0, curr_node);

  float t_entry, t_exit;

  // Test ray against the root node bounding box, encapsulating the entire world.
  // Get the distances along the ray that the ray enters and exits the box.
  bool intersects_node_box = ray_aabb_test(curr_node.mins, curr_node.maxs, ray_start, ray_recip_dir, t_entry, t_exit);
  if (!intersects_node_box || t_entry > 0.0) {
    return RAY_CROSS;
  }

  uint hit = RAY_MISS;

  float t_entry_prev = -inf;

  int node_index = 0;

  LightmapTri ttri;
  LightmapVertex tvert0, tvert1, tvert2;

  while (t_entry < t_exit && t_entry > t_entry_prev) {
    t_entry_prev = t_entry;

    // Find leaf node containing current entry point.
    vec3 p_entry = ray_start + (t_entry * ray_dir);
    while (curr_node.front_child >= 0 && curr_node.back_child >= 0) {
      if (p_entry[curr_node.axis] >= curr_node.dist) {
        // Traverse front child.
        node_index = curr_node.front_child;
        get_kd_node_0(curr_node.front_child, curr_node);
      } else {
        // Traverse back child.
        node_index = curr_node.back_child;
        get_kd_node_0(curr_node.back_child, curr_node);
      }
    }

    // Grab leaf data and node bounding box.
    get_kd_node_1(node_index, curr_node);
    get_kd_leaf(curr_node.leaf_num, leaf);

    // We've reached a leaf node.
    // Check intersection with triangles contained in current leaf node.
    for (uint i = leaf.first_triangle; i < (leaf.first_triangle + leaf.num_triangles); ++i) {
      uint tri_index = get_kd_tri(i);
      get_lightmap_tri_0(tri_index, ttri);

      // First check ray the triangle's bounding box.
      vec3 t0 = (ttri.mins - ray_start) * ray_recip_dir;
      vec3 t1 = (ttri.maxs - ray_start) * ray_recip_dir;
      vec3 tmin = min(t0, t1);
      vec3 tmax = max(t0, t1);
      if (max(tmin.x, max(tmin.y, tmin.z)) > min(tmax.x, min(tmax.y, tmax.z))) {
        // Doesn't intersect bounding box, can't intersect triangle itself.
        continue;
      }

      get_lightmap_tri_1(tri_index, ttri);

#ifdef TRACE_MODE_PROBES
      if (ignore_vertex_lit && ttri.page < -1) {
        continue;
      }
#endif

      get_lightmap_vertex_0(ttri.indices.x, tvert0);
      get_lightmap_vertex_0(ttri.indices.y, tvert1);
      get_lightmap_vertex_0(ttri.indices.z, tvert2);

      float hit_dist = inf;
      vec3 barycentric;
      bool ray_hit = ray_hits_triangle(ray_start, ray_dir, ray_len, bias, tvert0.position,
                                       tvert1.position, tvert2.position, hit_dist, barycentric);
      if (ray_hit) {
        vec3 normal = normalize(cross(tvert1.position - tvert0.position, tvert2.position - tvert0.position));
        bool backface = dot(normal, ray_dir) >= 0.0;
        if (!backface) {
          hit_dist = max(bias, hit_dist - bias);
        }
        if (hit_dist < t_exit) {
          float alpha = 1.0;
#ifdef TRACE_MODE_DIRECT
          if ((ttri.flags & TRIFLAGS_DONTCASTSHADOWS) != 0) {
            alpha = 0.0;

          } else
#endif
          if (ttri.page >= 0) {
            get_lightmap_vertex_1(ttri.indices.x, tvert0);
            get_lightmap_vertex_1(ttri.indices.y, tvert1);
            get_lightmap_vertex_1(ttri.indices.z, tvert2);
            if ((ttri.flags & TRIFLAGS_TRANSPARENT) != 0) {
              // Lightmapped triangle with alpha in albedo.  Grab alpha at
              // ray intersection point.
              vec3 uvw = vec3(barycentric.x * tvert0.uv + barycentric.y * tvert1.uv + barycentric.z * tvert2.uv, float(ttri.page));
              alpha = textureLod(luxel_albedo_samp, uvw, 0.0).a;
            }
          }
          if (alpha >= 0.5) {
            hit = backface ? RAY_BACK : RAY_FRONT;
            t_exit = hit_dist;
            o_bary = barycentric;
            tri = ttri;
            vert0 = tvert0;
            vert1 = tvert1;
            vert2 = tvert2;
          }
        }
      }
    }

    // Compute distance along ray to exit current node.
    float tmp_t_near, tmp_t_far;
    intersects_node_box = ray_aabb_test(curr_node.mins, curr_node.maxs, ray_start, ray_recip_dir, tmp_t_near, tmp_t_far);
    if (intersects_node_box) {
      // Set t_entry to be the entrance point of the next (neighboring) node.
      t_entry = tmp_t_far;
    } else {
      // Shouldn't be possible.
      break;
    }

    // Find the face of the leaf that the exit point is on.
    // Enter the node neighboring that leaf face.
    vec3 p_exit = ray_start + (t_entry * ray_dir);
    node_index = get_kd_neighbor(curr_node, leaf, p_exit);

    // Break if neighboring node not found, meaning we've exited the K-D tree.
    if (node_index < 0) {
      break;
    }

    get_kd_node_0(node_index, curr_node);
  }

  return hit;
}

const float PI = 3.14159265f;
const float GOLDEN_ANGLE = PI * (3.0 - sqrt(5.0));

// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
uint hash(uint value) {
  uint state = value * 747796405u + 2891336453u;
  uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
  return (word >> 22u) ^ word;
}

uint random_seed(ivec3 seed) {
  return hash(seed.x ^ hash(seed.y ^ hash(seed.z)));
}

// generates a random value in range [0.0, 1.0)
float randomize(inout uint value) {
  value = hash(value);
  return float(value / 4294967296.0);
}

// http://www.realtimerendering.com/raytracinggems/unofficial_RayTracingGems_v1.4.pdf (chapter 15)
vec3 generate_hemisphere_uniform_direction(inout uint noise) {
  float noise1 = randomize(noise);
  float noise2 = randomize(noise) * 2.0 * PI;

  float factor = sqrt(1 - (noise1 * noise1));
  return vec3(factor * cos(noise2), factor * sin(noise2), noise1);
}

vec3 generate_hemisphere_cosine_weighted_direction(inout uint noise) {
  float noise1 = randomize(noise);
  float noise2 = randomize(noise) * 2.0 * PI;

  return vec3(sqrt(noise1) * cos(noise2), sqrt(noise1) * sin(noise2), sqrt(1.0 - noise1));
}
