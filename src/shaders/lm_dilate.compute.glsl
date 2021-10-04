#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_dilate.compute.glsl
 * @author lachbr
 * @date 2021-09-23
 */

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

uniform sampler2DArray source_tex;
layout(rgba32f) uniform restrict writeonly image2DArray dest_image;

uniform ivec3 u_palette_size_page;
#define u_palette_size (u_palette_size_page.xy)
#define u_palette_page (u_palette_size_page.z)
uniform ivec3 u_region_ofs_grid_size;
#define u_region_ofs (u_region_ofs_grid_size.xy)
#define u_grid_size (u_region_ofs_grid_size.z)

void
main() {
  ivec2 palette_pos = ivec2(gl_GlobalInvocationID.xy) + u_region_ofs;
  if (any(greaterThanEqual(palette_pos, u_palette_size))) {
    // Too large, do nothing.
    return;
  }

  vec4 c = texelFetch(source_tex, ivec3(palette_pos, u_palette_page), 0);
	//sides first, as they are closer
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(-1, 0), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(0, 1), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(1, 0), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(0, -1), u_palette_page), 0);
	//endpoints second
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(-1, -1), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(-1, 1), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(1, -1), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(1, 1), u_palette_page), 0);

	//far sides third
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(-2, 0), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(0, 2), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(2, 0), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(0, -2), u_palette_page), 0);

	//far-mid endpoints
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(-2, -1), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(-2, 1), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(2, -1), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(2, 1), u_palette_page), 0);

	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(-1, -2), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(-1, 2), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(1, -2), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(1, 2), u_palette_page), 0);
	//far endpoints
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(-2, -2), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(-2, 2), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(2, -2), u_palette_page), 0);
	c = c.a > 0.5 ? c : texelFetch(source_tex, ivec3(palette_pos + ivec2(2, 2), u_palette_page), 0);

	imageStore(dest_image, ivec3(palette_pos, u_palette_page), c);
}
