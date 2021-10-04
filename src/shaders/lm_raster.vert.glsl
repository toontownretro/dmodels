#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_raster.vert.glsl
 * @author lachbr
 * @date 2021-09-21
 */

#extension GL_GOOGLE_include_directive : enable
#include "shaders/common.inc.glsl"

#include "shaders/lm_buffers.inc.glsl"

in vec4 p3d_Color;
in vec2 texcoord; // Base texture coordinate.

uniform vec4 p3d_ColorScale;

uniform ivec2 first_triangle;

out vec2 l_texcoord;
out vec3 l_world_normal;
out vec3 l_world_position;
out vec2 l_texcoord_lightmap;
out vec3 l_barycentric;
out vec4 l_color;
flat out uvec3 vertex_indices;
flat out vec3 face_normal;

uniform vec2 u_uv_offset;

void
main() {
  // NOTE: This requires non-indexed geometry.
  uint triangle_idx = first_triangle.x + (gl_VertexID / 3);
  uint triangle_local_idx = gl_VertexID % 3;

  LightmapTri tri = get_lightmap_tri(triangle_idx);
  vertex_indices = tri.indices;

  LightmapVertex tri_verts[3] = LightmapVertex[3](
    get_lightmap_vertex(vertex_indices.x),
    get_lightmap_vertex(vertex_indices.y),
    get_lightmap_vertex(vertex_indices.z)
  );

  if (triangle_local_idx == 0) {
    l_barycentric = vec3(1, 0, 0);

  } else if (triangle_local_idx == 1) {
    l_barycentric = vec3(0, 1, 0);

  } else {
    l_barycentric = vec3(0, 0, 1);
  }

  l_world_position = tri_verts[triangle_local_idx].position;
  l_world_normal = tri_verts[triangle_local_idx].normal;
  l_texcoord_lightmap = tri_verts[triangle_local_idx].uv;
  l_texcoord_lightmap += u_uv_offset;
  l_texcoord_lightmap = clamp(l_texcoord_lightmap, 0, 1);
  l_texcoord = texcoord;

  face_normal = normalize(
    cross(tri_verts[1].position - tri_verts[0].position,
          tri_verts[2].position - tri_verts[0].position));

  // Output the lightmap coordinate as the clip-space position for the vertex.
  gl_Position = vec4(l_texcoord_lightmap * 2.0 - 1.0, 0.0001, 1);

  vec4 v_color = p3d_Color;
  vec4 color_scale = p3d_ColorScale;
  GammaToLinear(v_color);
  GammaToLinear(color_scale);
  l_color = v_color * color_scale;
}
