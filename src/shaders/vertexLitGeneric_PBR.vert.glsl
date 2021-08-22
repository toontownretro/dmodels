#version 430

/**
 * COG INVASION ONLINE
 * Copyright (c) CIO Team. All rights reserved.
 *
 * @file vertexLitGeneric_PBR.vert.glsl
 * @author Brian Lach
 * @date March 09, 2019
 *
 */

#pragma optionNV(unroll all)

#extension GL_GOOGLE_include_directive : enable

#include "shaders/common.inc.glsl"
#include "shaders/common_shadows_vert.inc.glsl"
#include "shaders/common_animation_vert.inc.glsl"

uniform mat4 p3d_ModelViewProjectionMatrix;
uniform mat3 p3d_NormalMatrix;
in vec4 p3d_Vertex;
in vec3 p3d_Normal;

#ifdef STATIC_PROP_LIGHTING
    in vec3 static_vertex_lighting;
    out vec3 l_staticVertexLighting;
#endif

#if defined(NEED_TBN) || defined(NEED_EYE_VEC) || defined(NEED_WORLD_NORMAL)
    in vec4 p3d_Tangent;
    in vec4 p3d_Binormal;
    out vec4 l_tangent;
    out vec4 l_binormal;
#endif

uniform vec4 p3d_ColorScale;
in vec4 p3d_Color;
out vec4 l_vertexColor;

#if defined(NEED_WORLD_POSITION) || defined(NEED_WORLD_NORMAL)
    uniform mat4 p3d_ModelMatrix;
#endif

#if defined(NEED_WORLD_POSITION)
    out vec4 l_worldPosition;
#endif

#ifdef NEED_WORLD_NORMAL
    out vec4 l_worldNormal;
    out mat3 l_tangentSpaceTranspose;
#endif

#ifdef NEED_EYE_POSITION
    uniform mat4 p3d_ModelViewMatrix;
    out vec4 l_eyePosition;
#elif defined(NEED_TBN)
    uniform mat4 p3d_ModelViewMatrix;
#endif

#ifdef NEED_EYE_NORMAL
    out vec4 l_eyeNormal;
#endif

#ifdef NEED_WORLD_VEC
    uniform vec4 wspos_view;
    out vec4 l_worldEyeToVert;
#endif

in vec4 texcoord;
out vec4 l_texcoord;

#if defined(HAS_SHADOW_SUNLIGHT) || defined(HAS_SHADOWED_LIGHT)
    uniform struct p3d_LightSourceParameters {
        vec4 color;
        vec4 position;
        vec4 direction;
        vec4 spotParams;
        vec3 attenuation;
        #ifdef HAS_SHADOWED_LIGHT
            mat4 shadowViewMatrix;
            float hasShadows;
            #ifdef HAS_SHADOWED_POINT_LIGHT
                samplerCube shadowMapCube;
            #endif
            #ifdef HAS_SHADOWED_SPOTLIGHT
                sampler2D shadowMap2D;
            #endif
        #endif
    } p3d_LightSource[NUM_LIGHTS];

#ifdef HAS_SHADOW_SUNLIGHT
    uniform mat4 p3d_CascadeMVPs[PSSM_SPLITS];
    out vec4 l_pssmCoords[PSSM_SPLITS];
#endif

#ifdef HAS_SHADOWED_LIGHT
    out vec4 l_shadowCoords;
#endif

#endif

#ifdef PLANAR_REFLECTION
    out vec4 l_texcoordReflection;
    const mat4 scale_mat = mat4(vec4(0.5, 0.0, 0.0, 0.0),
                                vec4(0.0, 0.5, 0.0, 0.0),
                                vec4(0.0, 0.0, 0.5, 0.0),
                                vec4(0.5, 0.5, 0.5, 1.0));
#endif

#ifdef NUM_TEXTURES
    uniform mat4 p3d_TextureTransform[NUM_TEXTURES];
#endif

void main()
{
	vec4 finalVertex = p3d_Vertex;
    vec3 finalNormal = p3d_Normal;

    #if HAS_HARDWARE_SKINNING
        DoHardwareAnimation(finalVertex, finalNormal, p3d_Vertex, p3d_Normal);
    #endif

	gl_Position = p3d_ModelViewProjectionMatrix * finalVertex;

    // pass through the texcoord input as-is
    #ifdef BASETEXTURE_INDEX
        l_texcoord = p3d_TextureTransform[BASETEXTURE_INDEX] * texcoord;
    #else
        l_texcoord = texcoord;
    #endif

    #if defined(NEED_WORLD_POSITION)
        l_worldPosition = p3d_ModelMatrix * finalVertex;
    #endif

    #ifdef NEED_WORLD_NORMAL
        l_worldNormal = normalize(p3d_ModelMatrix * vec4(finalNormal, 0));
        l_tangentSpaceTranspose[0] = normalize(mat3(p3d_ModelMatrix) * p3d_Tangent.xyz);
        l_tangentSpaceTranspose[1] = normalize(mat3(p3d_ModelMatrix) * p3d_Binormal.xyz);
        l_tangentSpaceTranspose[2] = l_worldNormal.xyz;
    #endif

    #ifdef NEED_EYE_POSITION
        l_eyePosition = p3d_ModelViewMatrix * finalVertex;
    #endif

    #ifdef NEED_EYE_NORMAL
        l_eyeNormal = vec4(normalize(p3d_NormalMatrix * finalNormal), 0.0);
    #endif

    vec4 colorScale = p3d_ColorScale;
    vec4 vertexColor = p3d_Color;
    GammaToLinear(colorScale);
    GammaToLinear(vertexColor);
    l_vertexColor = vertexColor * colorScale;

    #ifdef NEED_TBN
        l_tangent = vec4(normalize(p3d_NormalMatrix * p3d_Tangent.xyz), 0.0);
        l_binormal = vec4(normalize(p3d_NormalMatrix * -p3d_Binormal.xyz), 0.0);
    #endif

    #ifdef NEED_WORLD_VEC
        l_worldEyeToVert = wspos_view - l_worldPosition;
    #endif

    //#ifdef HAS_SHADOWED_LIGHT
        //for (int i = 0; i < NUM_LIGHTS; i++) {
    //        l_shadowCoords = p3d_LightSource[0].color;//.shadowViewMatrix * vec4(l_eyePosition.xyz, 1.0);
            //l_shadowCoords.xyz = l_shadowCoords.xyz / l_shadowCoords.w;
        //}
    //#endif

    #ifdef HAS_SHADOW_SUNLIGHT
        ComputeSunShadowPositions(l_worldNormal.xyz, l_worldPosition,
                               p3d_LightSource[PSSM_LIGHT_ID].direction.xyz,
                               p3d_CascadeMVPs, l_pssmCoords);
    #endif

    #ifdef STATIC_PROP_LIGHTING
        l_staticVertexLighting = static_vertex_lighting;
    #endif

    #ifdef PLANAR_REFLECTION
        l_texcoordReflection = scale_mat * gl_Position;
    #endif
}
