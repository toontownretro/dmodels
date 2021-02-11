#version 330

/**
 * COG INVASION ONLINE
 * Copyright (c) CIO Team. All rights reserved.
 *
 * @file lightmappedGeneric_PBR.vert.glsl
 * @author Brian Lach
 * @date March 10, 2019
 *
 * @desc Shader for lightmapped geometry (brushes, displacements).
 *
 */

#extension GL_GOOGLE_include_directive : enable

#pragma optionNV(unroll all)

#include "shaders/common.inc.glsl"
#include "shaders/common_shadows_vert.inc.glsl"

in vec4 texcoord;
out vec4 l_texcoordBaseTexture;

in vec3 p3d_Normal;

#if defined(FLAT_LIGHTMAP) || defined(BUMPED_LIGHTMAP)
    in vec2 texcoord_lightmap;
    out vec4 l_texcoordLightmap;
#endif

#if defined(BUMPMAP) || defined(BUMPED_LIGHTMAP) || defined(ENVMAP) || defined(HAS_SHADOW_SUNLIGHT)
    out vec3 l_normal;
#endif

#ifdef BUMPMAP
    in vec3 p3d_Tangent;
    in vec3 p3d_Binormal;
    out vec4 l_tangent;
    out vec4 l_binormal;
    out vec4 l_texcoordBumpMap;
#endif

#if defined(ENVMAP) || defined(HAS_SHADOW_SUNLIGHT)
    uniform mat4 p3d_ModelMatrix;
    out vec4 l_worldNormal;
#endif

#if defined(ENVMAP) || defined(HAS_SHADOW_SUNLIGHT)
    uniform vec4 wspos_view;
    out vec4 l_worldEyeToVert;
    #ifdef BUMPMAP
        out mat3 l_tangentSpaceTranspose;
    #endif
#endif

#ifdef HAS_SHADOW_SUNLIGHT
    uniform mat4 pssmMVPs[PSSM_SPLITS];
    uniform vec3 sunVector[1];
    out vec4 l_pssmCoords[PSSM_SPLITS];
#endif

#if NUM_CLIP_PLANES > 0 || defined(FOG) || defined(BUMPMAP)
    uniform mat4 p3d_ModelViewMatrix;
#endif

#if NUM_CLIP_PLANES > 0 || defined(FOG)
    out vec4 l_eyePosition;
#endif

uniform mat4 p3d_ModelViewProjectionMatrix;
in vec4 p3d_Vertex;

uniform vec4 p3d_ColorScale;
in vec4 p3d_Color;
out vec4 l_vertexColor;

#ifdef PLANAR_REFLECTION
out vec4 l_texcoordReflection;
#endif

void main()
{
    gl_Position = p3d_ModelViewProjectionMatrix * p3d_Vertex;

    l_texcoordBaseTexture = texcoord;

    #if NUM_CLIP_PLANES > 0 || defined(FOG)
        l_eyePosition = p3d_ModelViewMatrix * p3d_Vertex;
    #endif

    #if defined(FLAT_LIGHTMAP) || defined(BUMPED_LIGHTMAP)
        l_texcoordLightmap = vec4(texcoord_lightmap, 0, 0);
    #endif

    #ifdef BUMPMAP
        l_tangent = normalize(vec4(mat3(p3d_ModelViewMatrix) * p3d_Tangent.xyz, 0.0));
        l_binormal = normalize(vec4(mat3(p3d_ModelViewMatrix) * -p3d_Binormal.xyz, 0.0));
        // Just use the base texture coord for the normal map.
        l_texcoordBumpMap = texcoord;
    #endif

    #if defined(BUMPMAP) || defined(BUMPED_LIGHTMAP)
        l_normal = p3d_Normal;
    #endif

    #if defined(ENVMAP) || defined(HAS_SHADOW_SUNLIGHT)
        vec4 worldPos = p3d_ModelMatrix * p3d_Vertex;
        l_worldNormal = normalize(p3d_ModelMatrix * vec4(p3d_Normal, 0));
    #endif

    #if defined(ENVMAP) || defined(HAS_SHADOW_SUNLIGHT)
        l_worldEyeToVert = wspos_view - worldPos;
        #ifdef BUMPMAP
            l_tangentSpaceTranspose[0] = normalize(mat3(p3d_ModelMatrix) * p3d_Tangent.xyz);
            l_tangentSpaceTranspose[1] = normalize(mat3(p3d_ModelMatrix) * -p3d_Binormal.xyz);
            l_tangentSpaceTranspose[2] = l_worldNormal.xyz;
        #endif
    #endif

    #ifdef HAS_SHADOW_SUNLIGHT
        ComputeShadowPositions(l_worldNormal.xyz, worldPos,
                               sunVector[0], pssmMVPs, l_pssmCoords);
    #endif

    vec4 colorScale = p3d_ColorScale;
    vec4 vertexColor = p3d_Color;
    GammaToLinear(colorScale);
    GammaToLinear(vertexColor);
	l_vertexColor = vertexColor * colorScale;

    #ifdef PLANAR_REFLECTION
        mat4 scale_mat = mat4(vec4(0.5, 0.0, 0.0, 0.0),
                              vec4(0.0, 0.5, 0.0, 0.0),
                              vec4(0.0, 0.0, 0.5, 0.0),
                              vec4(0.5, 0.5, 0.5, 1.0));
        l_texcoordReflection = (scale_mat * p3d_ModelViewProjectionMatrix) * p3d_Vertex;
    #endif
}
