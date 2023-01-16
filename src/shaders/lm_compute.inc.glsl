/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_compute.inc.glsl
 * @author brian
 * @date 2021-09-23
 */

#include "shaders/lm_buffers.inc.glsl"

const float RAY_EPSILON = 0.00001;

#define TRIFLAGS_NONE 0
#define TRIFLAGS_SKY 1
#define TRIFLAGS_TRANSPARENT 2
#define TRIFLAGS_DONTCASTSHADOWS 4
#define TRIFLAGS_DONTREFLECTLIGHT 8

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

	//if (abs(n_dot_dir) < RAY_EPSILON) {
//		return false;
	//}

	const vec3 e2 = (p0 - from) / n_dot_dir;
	const vec3 i = cross(dir, e2);

	barycentric.y = dot(i, e1);
	barycentric.z = dot(i, e0);
	barycentric.x = 1.0 - (barycentric.z + barycentric.y);
	dist = dot(triangle_normal, e2);

	return abs(n_dot_dir) >= RAY_EPSILON && (dist >= RAY_EPSILON) && (dist < max_dist) && all(greaterThanEqual(barycentric, vec3(0.0)));
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

  //if (fmax < 0.0) {
  //  return false;
  //}

  //if (fmin > fmax) {
  //  return false;
  //}

  t_near = max(0.0, fmin);
  t_far = fmax;

  return fmax >= 0 && fmin <= fmax;
}

void
get_kd_leaf_from_point(vec3 point, out int node_index) {
  node_index = 1;
  while (node_index > 0) {
    KDNode node;
    get_kd_node(node_index - 1, node);
    if (point[node.axis] >= node.dist) {
      // Traverse front child.
      node_index = node.front_child;
    } else {
      // Traverse back child.
      node_index = node.back_child;
    }
  }
}

// Note for KD node/leaf indices:
// 0 indicates a null node/leaf.
// a <0 index indicates a leaf, index into leaf array is ~index.
// a >0 index indicates a node. index into node array is (index - 1).

struct HitData {
  float hit_dist;
  vec3 normal;
  vec3 barycentric;
  uint triangle;
  LightmapVertex vert0, vert1, vert2;
  LightmapTri tri;
};

/**
 *
 */
uint ray_cast(vec3 ray_start, vec3 ray_end, float bias
#ifndef TRACE_NO_ALPHA_TEST
              , in sampler2DArray luxel_albedo_samp
#endif
              , int start_index, out HitData hit_data
              ) {

  const float inf = 999999999.0;

  vec3 ray_vec = ray_end - ray_start;
  float ray_len = length(ray_vec);
  vec3 ray_dir = normalize(ray_vec);
  vec3 ray_recip_dir = 1.0 / ray_dir;

  float t_entry, t_exit;

  // Test ray against the root node bounding box, encapsulating the entire world.
  // Get the distances along the ray that the ray enters and exits the box.
  ray_aabb_test(scene_mins, scene_maxs, ray_start, ray_recip_dir, t_entry, t_exit);

  uint hit = RAY_MISS;

  float t_entry_prev = -inf;

  int node_index = start_index;

  while (node_index != 0 && t_entry < t_exit && t_entry > t_entry_prev) {
    t_entry_prev = t_entry;

    // Find leaf node containing current entry point.
    vec3 p_entry = ray_start + (t_entry * ray_dir);
    while (node_index > 0) {
      KDNode node;
      get_kd_node(node_index - 1, node);
      if (p_entry[node.axis] >= node.dist) {
        // Traverse front child.
        node_index = node.front_child;
      } else {
        // Traverse back child.
        node_index = node.back_child;
      }
    }

    // Can this happen?
    if (node_index == 0) {
      break;
    }

    // Reached a leaf, fetch the leaf data.
    KDLeaf leaf;
    get_kd_leaf(~node_index, leaf);

    // Check intersection with triangles contained in current leaf node.
    uint last_tri = (leaf.first_triangle + leaf.num_triangles);
    for (uint i = leaf.first_triangle; i < last_tri; ++i) {
      uint tri_index = get_kd_tri(i);

      LightmapTri ttri;
      get_lightmap_tri(tri_index, ttri);

#if defined(TRACE_MODE_DIRECT)
      if ((ttri.flags & TRIFLAGS_DONTCASTSHADOWS) != 0) {
        continue;
      }
#elif defined(TRACE_MODE_INDIRECT) || defined(TRACE_MODE_PROBES)
      if ((ttri.flags & TRIFLAGS_DONTREFLECTLIGHT) != 0) {
        continue;
      }
#endif

#ifdef TRACE_MODE_PROBES
      if (ttri.page < -1) {
        continue;
      }
#endif

      // First check ray the triangle's bounding box.
      vec3 t0 = (ttri.mins - ray_start) * ray_recip_dir;
      vec3 t1 = (ttri.maxs - ray_start) * ray_recip_dir;
      vec3 tmin = min(t0, t1);
      vec3 tmax = max(t0, t1);
      if (max(tmin.x, max(tmin.y, tmin.z)) > min(tmax.x, min(tmax.y, tmax.z))) {
        // Doesn't intersect bounding box, can't intersect triangle itself.
        continue;
      }

      LightmapVertex tvert0, tvert1, tvert2;
      get_lightmap_vertex(ttri.indices.x, tvert0);
      get_lightmap_vertex(ttri.indices.y, tvert1);
      get_lightmap_vertex(ttri.indices.z, tvert2);

      vec3 normal = normalize(cross(tvert1.position - tvert0.position, tvert2.position - tvert0.position));
      bool backface = dot(normal, ray_dir) >= 0.0;

#ifdef TRACE_IGNORE_BACKFACE
      if (backface) {
        continue;
      }
#endif

      float hit_dist = inf;
      vec3 barycentric;
      bool ray_hit = ray_hits_triangle(ray_start, ray_dir, ray_len, bias, tvert0.position,
                                       tvert1.position, tvert2.position, hit_dist, barycentric);
      if (ray_hit) {
        if (!backface) {
          hit_dist = max(bias, hit_dist - bias);
        }
        if (hit_dist < t_exit) {
          float alpha = 1.0;
#ifndef TRACE_NO_ALPHA_TEST
          if (ttri.page >= 0 && (ttri.flags & TRIFLAGS_TRANSPARENT) != 0) {
            // Lightmapped triangle with alpha in albedo.  Grab alpha at
            // ray intersection point.
            vec3 uvw = vec3(barycentric.x * tvert0.uv + barycentric.y * tvert1.uv + barycentric.z * tvert2.uv, float(ttri.page));
            alpha = textureLod(luxel_albedo_samp, uvw, 0.0).a;
          }
#endif // TRACE_NO_ALPHA_TEST
          if (alpha >= 0.5) {
            hit = backface ? RAY_BACK : RAY_FRONT;
            t_exit = hit_dist;
            hit_data.hit_dist = hit_dist;
            hit_data.normal = normal;
            hit_data.barycentric = barycentric;
            hit_data.triangle = tri_index;
            hit_data.tri = ttri;
            hit_data.vert0 = tvert0;
            hit_data.vert1 = tvert1;
            hit_data.vert2 = tvert2;
          }
        }
      }
    }

    // Determine the node or leaf the ray will visit next.
    int exit_side;
    t_entry = get_kd_neighbor_new(leaf, ray_start, ray_recip_dir, exit_side);
    node_index = leaf.neighbors[exit_side];
  }

  return hit;
}

const float PI = 3.141592653589793;
const float GOLDEN_ANGLE = PI * (3.0 - sqrt(5.0));
#define COSINE_A1 ((2.0 * PI) / 3.0)
#define COSINE_A2 (PI / 4.0)

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

float calc_halton(int n, int base) {
  float r = 0.0;
  float f = 1.0;
  while (n > 0) {
    f = f / float(base);
    r = r + f * float(n % base);
    n = int(floor(float(n) / float(base)));
  }
  return r;
}

vec2 sample_halton(int n) {
  return vec2(calc_halton(n + 1, 2), calc_halton(n + 1, 3));
}

vec3 halton_hemisphere_direction(int index, int total_rays, vec2 offset) {
  vec2 uv = sample_halton(index);

  uv.x = fract(uv.x + offset.x);
  uv.y = fract(uv.y + offset.y);

#if 1
  float noise1 = uv.x;
  float noise2 = uv.y * 2.0 * PI;

  return vec3(sqrt(noise1) * cos(noise2), sqrt(noise1) * sin(noise2), sqrt(1.0 - noise1));
#else

  float cos_theta = uv.x;
  float sin_theta = sqrt(1.0 - cos_theta * cos_theta);
  float sin_phi, cos_phi;
  float phi = uv.y * 2 * PI;
  sin_phi = sin(phi);
  cos_phi = cos(phi);

  return vec3(cos_phi * sin_theta, sin_phi * sin_theta, cos_theta);
#endif
}

mat3
make_xi_mat(vec2 x) {
  return mat3(
    vec3(1.0, 0.0, 0.0),
    vec3(0, x.x, x.y),
    vec3(0, -x.y, x.x)
  );
}

mat3
make_x_mat(vec2 x) {
  return mat3(
    vec3(1.0, 0.0, 0.0),
    vec3(0, x.y, x.x),
    vec3(0, -x.x, x.y)
  );
}

mat3
make_y_mat(vec2 y) {
  return mat3(
    vec3(y.y, 0, -y.x),
    vec3(0.0, 1.0, 0.0),
    vec3(y.x, 0.0, y.y)
  );
}

mat3
make_z_mat(vec2 z) {
  return mat3(
    vec3(z.y, -z.x, 0.0),
    vec3(z.x, z.y, 0.0),
    vec3(0.0, 0.0, 1.0)
  );
}

mat3
look_at(vec3 fwd) {
  vec3 up = vec3(0.0, 0.0, 1.0);

  vec2 z = vec2(fwd.x, fwd.y);
  float d = dot(z, z);
  if (d == 0.0) {
    z = vec2(0.0, 1.0);
  } else {
    z /= sqrt(d);
  }

  vec2 x = vec2(fwd.x * z.x + fwd.y * z.y, fwd.z);
  d = dot(x, x);
  if (d == 0.0) {
    x = vec2(1.0, 0.0);
  } else {
    x /= sqrt(d);
  }

  vec2 y = vec2(up.x * z.y - up.y * z.x,
                -up.x * x.y * z.x - up.y * x.y * z.y + up.z * x.x);
  d = dot(y, y);
  if (d == 0.0) {
    y = vec2(0.0, 1.0);
  } else {
    y /= sqrt(d);
  }

  return make_xi_mat(x) * make_y_mat(z) * make_z_mat(y);
}
