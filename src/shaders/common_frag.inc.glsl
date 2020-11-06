/**
 * COG INVASION ONLINE
 * Copyright (c) CIO Team. All rights reserved.
 *
 * @file common_frag.inc.glsl
 * @author Brian Lach
 * @date October 30, 2018
 *
 */

#ifndef COMMON_FRAG_INC_GLSL
#define COMMON_FRAG_INC_GLSL

#include "shaders/common.inc.glsl"

//#ifdef HDR
//uniform float p3d_ExposureScale;
//#endif

// Define useful preset color attachment locations.
#define COLOR_LOCATION 0
#define AUX_NORMAL_LOCATION 1
#define AUX_ARME_LOCATION 2
#define AUX_BLOOM_LOCATION 3

bool AlphaTest(float alpha)
{
	#if ALPHA_TEST == 1 // never draw
		return false;

	#elif ALPHA_TEST == 2 // less
		return alpha < ALPHA_TEST_REF;

	#elif ALPHA_TEST == 3 // equal
		return alpha == ALPHA_TEST_REF;

	#elif ALPHA_TEST == 4 // less equal
		return alpha <= ALPHA_TEST_REF;

	#elif ALPHA_TEST == 5 // greater
		return alpha > ALPHA_TEST_REF;

	#elif ALPHA_TEST == 6 // not equal
		return alpha != ALPHA_TEST_REF;

	#elif ALPHA_TEST == 7 // greater equal
		return alpha >= ALPHA_TEST_REF;

	#else
        return true;

    #endif
}

bool ClipPlaneTest(vec4 position, vec4 clipPlane)
{
	return (dot(clipPlane, position) >= 0);
}

void FinalOutput(inout vec4 color)
{
//#ifndef HDR
//	color.rgb = clamp(color.rgb, 0, 1);
//#endif
}

#endif // COMMON_FRAG_INC_GLSL
