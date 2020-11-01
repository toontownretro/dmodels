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

#ifndef PSSM_SPLITS
#define PSSM_SPLITS 3
#define NORMAL_OFFSET_SCALE 0
#define SHADOW_TEXEL_SIZE 0
#endif

const vec4 lClipScale1 = vec4(0.5, 0.5, 0.5, 1.0);
const vec4 lClipScale2 = vec4(0.5, 0.5, 0.5, 0.0);

void ComputeShadowPositions(vec3 worldNormal, vec4 worldPosition, vec3 sunVector,
                            mat4 pssmMVPs[PSSM_SPLITS], inout vec4 pssmCoords[PSSM_SPLITS])
{
    vec4 lightclip;
    #ifdef NORMAL_OFFSET_UV_SPACE
        vec4 uvOffset;
    #endif

    // Compute a normal offset bias for the shadow position.
    float cosSun = dot(-sunVector, worldNormal.xyz);
    float slopeScale = clamp(1 - cosSun, 0, 1);
    // NORMAL_OFFSET_SCALE: constant value suppled in config prc
    float normalOffsetScale = slopeScale * NORMAL_OFFSET_SCALE * SHADOW_TEXEL_SIZE;

    vec4 shadowOffset = vec4(worldNormal.xyz * normalOffsetScale, 0.0);
    vec4 pushedVertex = worldPosition;// + shadowOffset;

    for (int i = 0; i < PSSM_SPLITS; i++)
    {
        #if 0 //def NORMAL_OFFSET_UV_SPACE
            lightclip = vec4(
                (pssmMVPs[i] * pushedVertex).xy,
                (pssmMVPs[i] * vec4(worldPosition.xyz, 1)).zw
            );
        #else
            lightclip = pssmMVPs[i] * vec4(pushedVertex.xyz, 1);
        #endif

        pssmCoords[i] = vec4((lightclip.xyz / lightclip.w) * vec3(0.5) + vec3(0.5), 1);
    }
}

#endif // COMMON_SHADOWS_VERT_INC_GLSL
