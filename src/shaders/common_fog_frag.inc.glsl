/**
 * COG INVASION ONLINE
 * Copyright (c) CIO Team. All rights reserved.
 *
 * @file common_fog_frag.inc.glsl
 * @author Brian Lach
 * @date October 31, 2018
 *
 */

#ifndef COMMON_FOG_FRAG_INC_GLSL
#define COMMON_FOG_FRAG_INC_GLSL

#include "common.inc.glsl"

#ifdef FOG

#define FOG_LINEAR 				0
#define FOG_EXPONENTIAL 		1
#define FOG_EXPONENTIAL_SQUARED 2

uniform struct p3d_FogParameters {
  	vec4 color;
  	float density;
  	float start;
  	float end;
  	float scale; // 1.0 / (end - start)
} p3d_Fog;

void GetFogLinear(inout vec4 result, vec4 fogColor, float dist, vec4 fogData)
{
	float fogFactor = clamp(1.0 - ((fogData.z - dist) * fogData.w), 0, 1);
	result.rgb = mix(result.rgb, fogColor.rgb, fogFactor * fogFactor);
}

void GetFogExp(inout vec4 result, vec4 fogColor, float dist, float density)
{
	result.rgb = mix(fogColor.rgb, result.rgb, clamp(exp2(density * dist * -1.442695), 0, 1));
}

void GetFogExpSqr(inout vec4 result, vec4 fogColor, float dist, vec4 fogData)
{
	result.rgb = mix(fogColor.rgb, result.rgb, clamp(exp2(fogData.x * fogData.x * dist * dist * -1.442695), 0, 1));
}

void ApplyFog(inout vec4 result, vec4 eyePos)
{
    float dist = length(eyePos.xyz);

	#if defined(BLEND_MODULATE)
		vec4 fogColor = vec4(0.5, 0.5, 0.5, 1.0);
	#elif defined(BLEND_ADDITIVE)
		vec4 fogColor = vec4(0, 0, 0, 1.0);
	#else
		vec4 fogColor = p3d_Fog.color;
		GammaToLinear(fogColor);
	#endif

	#if FOG == FOG_EXPONENTIAL
    	GetFogExp(result, fogColor, dist, p3d_Fog.density);
	#elif FOG == FOG_EXPONENTIAL_SQUARED
		GetFogExpSqr(result, fogColor, dist, vec4(p3d_Fog.density, p3d_Fog.start, p3d_Fog.end, p3d_Fog.scale));
	#elif FOG == FOG_LINEAR
		GetFogLinear(result, fogColor, dist, vec4(p3d_Fog.density, p3d_Fog.start, p3d_Fog.end, p3d_Fog.scale));
	#endif
}

#endif

#endif // COMMON_FOG_FRAG_INC_GLSL
