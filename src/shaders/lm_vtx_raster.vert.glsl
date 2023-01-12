#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_vtx_raster.vert.glsl
 * @author brian
 * @date 2022-06-06
 */

// Outputs per-vertex albedo for vertex-lit geometry.

uniform mat4 p3d_ModelMatrix;

in vec2 texcoord;

in vec4 p3d_Color;
uniform vec4 p3d_ColorScale;

out vec4 l_color;
out vec2 l_texcoord;

uniform uvec2 u_vtx_palette_size;
uniform uvec2 u_first_vertex;

void
main() {
  l_color = vec4(pow(p3d_Color.rgb, vec3(2.2)), p3d_Color.a);
  l_color *= vec4(pow(p3d_ColorScale.rgb, vec3(2.2)), p3d_ColorScale.a);

  l_texcoord = texcoord;

  uint vtx_index = u_first_vertex.x + gl_VertexID;

  vec2 palette_coord;
  palette_coord.y = vtx_index / u_vtx_palette_size.x;
  palette_coord.x = vtx_index % u_vtx_palette_size.x;
  // Center sample inside texel.
  palette_coord += vec2(0.5);
  palette_coord /= vec2(float(u_vtx_palette_size.x), float(u_vtx_palette_size.y));

  // Output position in vertex palette UV coordinates.
  gl_Position = vec4(palette_coord * 2 - 1, 0.0, 1.0);

  //gl_PointSize = 1;
}
