#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_vtx_raster.frag.glsl
 * @author brian
 * @date 2022-06-06
 */

layout(location = 0) out vec4 albedo_output;

in vec4 l_color;
in vec2 l_texcoord;

uniform sampler2D base_texture_sampler;

void
main() {
  albedo_output = vec4(textureLod(base_texture_sampler, l_texcoord, 0).rgb * l_color.rgb, 1.0);
}
