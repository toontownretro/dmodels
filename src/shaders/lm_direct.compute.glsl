#version 450

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file lm_direct.compute.glsl
 * @author lachbr
 * @date 2021-09-23
 */

// Compute shader for computing direct light into lightmaps.

#extension GL_GOOGLE_include_directive : enable
#include "shaders/lm_buffers.inc.glsl"


