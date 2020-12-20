/**
 * COG INVASION ONLINE
 * Copyright (c) CIO Team. All rights reserved.
 *
 * @file common_shadows_vert.inc.glsl
 * @author Brian Lach
 * @date October 30, 2018
 *
 */

#ifndef COMMON_SHADOWS_VERT_INC_GLSL
#define COMMON_SHADOWS_VERT_INC_GLSL

#include "common.inc.glsl"

#ifndef PSSM_SPLITS
#define PSSM_SPLITS 3
#define NORMAL_OFFSET_SCALE 0
#define SHADOW_TEXEL_SIZE 0
#endif

// FIXME: Make these configurable
#define SLOPE_BIAS 0.11
#define NORMAL_BIAS 0.3
#define FIXED_BIAS 0.05

vec2 GetShadowBias(vec3 n, vec3 l) {
    float cosAlpha = clamp(dot(n, l), 0, 1);
    float offsetScaleN = sqrt(1 - cosAlpha * cosAlpha);
    float offsetScaleL = offsetScaleN / cosAlpha;
    return vec2(offsetScaleN, min(2, offsetScaleL));
}

float GetFixedBias(int cascade) {
    return FIXED_BIAS * 0.001 * (1 + 1.5 * cascade);
}

vec3 GetBiasedPos(vec3 pos, float slopeBias, float normalBias, vec3 normal, vec3 light) {
    vec2 offsets = GetShadowBias(normal, light);
    pos += normal * offsets.x * normalBias;
    pos += light * offsets.y * slopeBias;
    return pos;
}

vec3 GetSplitBiasedPos(vec3 pos, vec3 normal, vec3 sunVector, int cascade) {
    float slopeBias = SLOPE_BIAS * 0.1 * (1 + 0.2 * cascade);
    const float normalBias = NORMAL_BIAS * 0.1;

    vec3 biasedPos = GetBiasedPos(pos, slopeBias, normalBias, normal, sunVector);
    return biasedPos;
}

void ComputeShadowPositions(vec3 worldNormal, vec4 eyePosition, mat4 shadowViewMatrix, inout vec4 shadowCoords) {
    shadowCoords = shadowViewMatrix * vec4(eyePosition.xyz, 1.0);
}

void ComputeSunShadowPositions(vec3 worldNormal, vec4 worldPosition, vec3 sunVector,
                            mat4 pssmMVPs[PSSM_SPLITS], inout vec4 pssmCoords[PSSM_SPLITS])
{
    // The light direction is the direction that the light is pointing,
    // but we want the direction *to* the light.
    //sunVector = -sunVector;

    for (int i = 0; i < PSSM_SPLITS; i++) {
        vec3 biasedPos = GetSplitBiasedPos(worldPosition.xyz, worldNormal, sunVector, i);
        vec3 projected = Project(pssmMVPs[i], biasedPos);
        projected.z -= GetFixedBias(i);
        pssmCoords[i] = vec4(projected, 1);
    }

}

#endif // COMMON_SHADOWS_VERT_INC_GLSL
