/**
 * COG INVASION ONLINE
 * Copyright (c) CIO Team. All rights reserved.
 *
 * @file common_brdf_frag.inc.glsl
 * @author Brian Lach
 * @date April 04, 2019
 *
 */

#ifndef COMMON_BRDF_FRAG_INC_GLSL
#define COMMON_BRDF_FRAG_INC_GLSL

const float PI = 3.14159265359;

// Fresnel term F( v, h )
// Fnone( v, h ) = F(0�) = specularColor
vec3 Fresnel_Schlick( vec3 specularColor, float VdotH )
{
    return specularColor + ( 1.0 - specularColor ) * pow( clamp(1.0 - VdotH, 0, 1), 5.0 );
}

vec3 CookTorrance(vec3 F, vec3 G, float D, vec3 NdotL, float NdotV)
{
    return F * G * D;
}

float MicrofacetDistributionTerm(float alpha, float NdotH)
{
		float alpha2 = alpha * alpha;
    float f = (NdotH * NdotH) * (alpha2 - 1.0) + 1.0;
    return alpha2 / (PI * f * f);
}

vec3 GeometricOcclusionTerm(float alpha, vec3 NdotL, float NdotV)
{
		float alpha2 = alpha * alpha;
    vec3 attenuationV = NdotL * sqrt(NdotV * NdotV * (1.0 - alpha2) + alpha2);
		vec3 attenuationL = NdotV * sqrt(NdotL * NdotL * (1.0 - alpha2) + alpha2);
    return max(vec3(0.0), 0.5 / (attenuationV + attenuationL));
}

// Environment BRDF approximations
// see s2013_pbs_black_ops_2_notes.pdf
float a1vf( float g )
{
	return ( 0.25 * g + 0.75 );
}

float a004( float g, float NdotV )
{
	float t = min( 0.475 * g, exp2( -9.28 * NdotV ) );
	return ( t + 0.0275 ) * g + 0.015;
}

float a0r( float g, float NdotV )
{
	return ( ( a004( g, NdotV ) - a1vf( g ) * 0.04 ) / 0.96 );
}

vec3 EnvironmentBRDF( float g, float NdotV, vec3 rf0 )
{
	vec4 t = vec4( 1.0 / 0.96, 0.475, ( 0.0275 - 0.25 * 0.04 ) / 0.96, 0.25 );
	t *= vec4( g, g, g, g );
	t += vec4( 0.0, 0.0, ( 0.015 - 0.75 * 0.04 ) / 0.96, 0.75 );
	float a0 = t.x * min( t.y, exp2( -9.28 * NdotV ) ) + t.z;
	float a1 = t.w;

	return clamp( a0 + rf0 * ( a1 - a0 ), 0, 1 );
}

#endif // COMMON_BRDF_FRAG_INC_GLSL
