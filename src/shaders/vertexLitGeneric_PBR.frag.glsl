#version 430

#extension GL_ARB_explicit_attrib_location : enable
#extension GL_ARB_gpu_shader5 : enable
#extension GL_GOOGLE_include_directive : enable

/**
 * COG INVASION ONLINE
 * Copyright (c) CIO Team. All rights reserved.
 *
 * @file vertexLitGeneric_PBR.frag.glsl
 * @author Brian Lach
 * @date March 09, 2019
 *
 * This is our big boy shader -- used for most models,
 * in particular ones that should be dynamically lit by light sources.
 *
 * Supports a plethora of material effects:
 * - $basetexture
 * - $bumpmap
 * - $envmap
 * - $phong
 * - $rimlight
 * - $halflambert
 * - $lightwarp
 * - $alpha/$translucent
 * - $selfillum
 *
 * And these render effects:
 * - Clip planes
 * - Flat colors
 * - Vertex colors
 * - Color scale
 * - Fog
 * - Lighting
 * - Cascaded shadow maps for directional lights
 * - Alpha testing
 * - Output normals/glow to auxiliary buffer
 *
 * Will eventually support:
 * - $detail (finer detail at close distance)
 *
 */

#pragma optionNV(unroll all)

//#define HALFLAMBERT 1

#include "shaders/common_lighting_frag.inc.glsl"
#include "shaders/common_fog_frag.inc.glsl"
#include "shaders/common_frag.inc.glsl"
#include "shaders/common_sequences.inc.glsl"

#ifdef STATIC_PROP_LIGHTING
    in vec3 l_staticVertexLighting;
#endif

#ifdef NEED_WORLD_POSITION
    in vec4 l_worldPosition;
#endif

#ifdef NEED_WORLD_NORMAL
    in vec4 l_worldNormal;
    in mat3 l_tangentSpaceTranspose;
#endif

#ifdef NEED_EYE_POSITION
    in vec4 l_eyePosition;
#endif

#ifdef NEED_EYE_NORMAL
    in vec4 l_eyeNormal;
#endif

in vec4 l_texcoord;

#ifdef BASETEXTURE
    uniform sampler2D baseTextureSampler;
#elif defined(BASECOLOR)
    uniform vec4 baseColor;
#endif

#ifdef ENVMAP
    uniform samplerCube envmapSampler;
    uniform sampler2D brdfLut;
    uniform vec3 envmapTint;
#endif

uniform vec4 u_armeParams;

#ifdef AO_MAP
    uniform sampler2D aoSampler;
#endif

#ifdef ROUGHNESS_MAP
    uniform sampler2D roughnessSampler;
#elif defined(GLOSS_MAP)
    uniform sampler2D glossSampler;
#endif

#ifdef METALNESS_MAP
    uniform sampler2D metalnessSampler;
#endif

#ifdef EMISSION_MAP
    uniform sampler2D emissionSampler;
#endif

#ifdef SPECULAR_MAP
    uniform sampler2D specularSampler;
#endif

#ifdef SELFILLUM
    uniform vec3 selfillumTint;
#endif

#ifdef NEED_WORLD_VEC
    in vec4 l_worldEyeToVert;
#endif

#ifdef RIMLIGHT
    uniform vec2 rimlightParams;
#endif

#ifdef BUMPMAP
    uniform sampler2D bumpSampler;
#endif

#ifdef NEED_TBN
    in vec4 l_tangent;
    in vec4 l_binormal;
#endif

in vec4 l_vertexColor;

#if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
uniform vec4 p3d_WorldClipPlane[NUM_CLIP_PLANES];
#endif

uniform vec4 p3d_ColorScale;

#ifdef LIGHTING

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
        uniform sampler2DArray p3d_CascadeShadowMap;
        uniform mat4 p3d_CascadeMVPs[PSSM_SPLITS];
        in vec4 l_pssmCoords[PSSM_SPLITS];
        uniform vec4 wspos_view;
    #endif

    #ifdef HAS_SHADOWED_LIGHT
        in vec4 l_shadowCoords;
    #endif

#endif // LIGHTING

#ifdef AMBIENT_LIGHT
    uniform struct {
      vec4 ambient;
    } p3d_LightModel;

#elif defined(AMBIENT_PROBE)
    uniform vec3 ambientProbe[9];
#endif

#ifdef PLANAR_REFLECTION
    in vec4 l_texcoordReflection;
    uniform sampler2D reflectionSampler;
#endif

#ifdef HAS_LIGHTMAP
    in vec2 l_texcoordLightmap;
    uniform sampler2D lightmapSampler;
#endif

uniform vec4 p3d_TexAlphaOnly;

layout(location = COLOR_LOCATION) out vec4 outputColor;

// Auxilliary bitplanes for deferred passes
#ifdef NEED_AUX_NORMAL
    layout(location = AUX_NORMAL_LOCATION) out vec4 o_aux_normal;
#endif
#ifdef NEED_AUX_ARME
    layout(location = AUX_ARME_LOCATION) out vec4 o_aux_arme;
#endif
#ifdef NEED_AUX_BLOOM
    layout(location = AUX_BLOOM_LOCATION) out vec4 o_aux_bloom;
#endif

// Monte Carlo integration, approximate analytic version based on Dimitar Lazarov's work
// https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile
vec3 envBRDFApprox(vec3 SpecularColor, float Roughness, float NoV) {
  const vec4 c0 = vec4(-1, -0.0275, -0.572, 0.022);
  const vec4 c1 = vec4(1, 0.0425, 1.04, -0.04);
  vec4 r = Roughness * c0 + c1;
  float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
  vec2 AB = vec2(-1.04, 1.04) * a004 + r.zw;
  return SpecularColor * AB.x + AB.y;
}

void main()
{
    // Clipping first!
    #if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
        for (int i = 0; i < NUM_CLIP_PLANES; i++)
        {
            if (!ClipPlaneTest(l_worldPosition, p3d_WorldClipPlane[i]))
            {
                // pixel outside of clip plane interiors
                discard;
            }
        }
    #endif

    #ifdef BASETEXTURE
        vec4 albedo = SampleAlbedo(baseTextureSampler, l_texcoord.xy);
        albedo.a = clamp(albedo.a, 0, 1);
    #elif defined(BASECOLOR)
        vec4 albedo = baseColor;
    #else
        vec4 albedo = vec4(1, 1, 1, 1);
    #endif
    albedo += p3d_TexAlphaOnly;
    // Modulate albedo with vertex/flat colors
    albedo *= l_vertexColor;
    // Explicit alpha value from material.
    #ifdef ALPHA
        albedo.a *= ALPHA;
    #endif

    #ifdef ALPHA_TEST
        if (!AlphaTest(albedo.a))
        {
            discard;
        }
    #endif

    #ifdef NEED_EYE_NORMAL
        vec4 finalEyeNormal = normalize(l_eyeNormal);
    #else
        vec4 finalEyeNormal = vec4(0.0);
    #endif

    #ifdef NEED_WORLD_NORMAL
        vec4 finalWorldNormal = normalize(l_worldNormal);
        mat3 tangentSpaceTranspose = l_tangentSpaceTranspose;
        tangentSpaceTranspose[2] = finalWorldNormal.xyz;
    #else
        vec4 finalWorldNormal = vec4(0.0);
    #endif

    #ifdef BUMPMAP
        vec3 tangentSpaceNormal = GetTangentSpaceNormal(bumpSampler, l_texcoord.xy);
        #ifdef SSBUMP
            // GetTangentSpaceNormal assumes a regular normal map and makes the
            // vector signed.  We don't want this for SSBump, so make it
            // unsigned again.
            tangentSpaceNormal = tangentSpaceNormal * 0.5 + 0.5;
        #endif
        #if defined(NEED_EYE_NORMAL)
            TangentToEye(finalEyeNormal.xyz, l_tangent.xyz,
                         l_binormal.xyz, tangentSpaceNormal);
        #endif
        #if defined(NEED_WORLD_NORMAL)
            TangentToWorld(finalWorldNormal.xyz, tangentSpaceTranspose, tangentSpaceNormal);
        #endif
    #else
        vec3 tangentSpaceNormal = vec3(0);
    #endif

    #ifdef NEED_WORLD_NORMAL
        float NdotV = abs(dot(finalWorldNormal.xyz, normalize(l_worldEyeToVert.xyz))) + 0.001;
    #else
        float NdotV = 1.0;
    #endif

    // AO/Roughness/Metallic/Emissive properties
    float ao = clamp(u_armeParams.x, 0, 1);
    float perceptualRoughness = 1.0;//u_armeParams.y;
    float metalness = clamp(u_armeParams.z, 0, 1);
    float emission = clamp(u_armeParams.w, 0, 1);
    #ifdef AO_MAP
        ao = texture(aoSampler, l_texcoord.xy).r;
    #endif
    #ifdef ROUGHNESS_MAP
        perceptualRoughness *= texture(roughnessSampler, l_texcoord.xy).r;
    #elif defined(GLOSS_MAP)
        perceptualRoughness *= pow(1 - texture(glossSampler, l_texcoord.xy).r, 2);
    #endif
    #ifdef METALNESS_MAP
        metalness = texture(metalnessSampler, l_texcoord.xy).r;
    #endif
    #ifdef EMISSION_MAP
        emission = texture(emissionSampler, l_texcoord.xy).r;
    #endif

    perceptualRoughness = clamp(perceptualRoughness, 0, 1);

    float roughness = perceptualRoughness * perceptualRoughness;

    /////////////////////////////////////////////////////
    // Aux bitplane outputs
    #ifdef NEED_AUX_NORMAL
        //#ifdef ENVMAP
        //    int hasEnvmap = 1;
        //#else
        //    int hasEnvmap = 0;
        //#endif
        o_aux_normal = vec4((finalWorldNormal.xyz * 0.5) + 0.5, 1);
    #endif
    #ifdef NEED_AUX_ARME
        o_aux_arme = vec4(ao, perceptualRoughness, metalness, emission);
    #endif
    /////////////////////////////////////////////////////

    vec3 specularColor = mix(vec3(0.04), albedo.rgb, metalness);

    #ifdef SPECULAR_MAP
        float specularScale = texture(specularSampler, l_texcoord.xy).r;
    #else
        float specularScale = 1.0;
    #endif

    #ifdef LIGHTING

        // Initialize our lighting parameters
        LightingParams_t params = newLightingParams_t(
            l_worldPosition,
            normalize(l_worldEyeToVert.xyz),
            normalize(finalWorldNormal.xyz),
            NdotV,
            roughness,
            metalness,
            specularColor,
            specularScale,
            albedo.rgb
            );

        vec3 ambientDiffuse = vec3(0, 0, 0);

        #if defined(AMBIENT_LIGHT)
            ambientDiffuse += p3d_LightModel.ambient.rgb;

        #elif defined(AMBIENT_PROBE)
            // Evaluate spherical harmonics.
            vec3 wnormal = finalWorldNormal.xyz;
            const float c1 = 0.429043;
            const float c2 = 0.511664;
            const float c3 = 0.743125;
            const float c4 = 0.886227;
            const float c5 = 0.247708;
            ambientDiffuse += (c1 * ambientProbe[8] * (wnormal.x * wnormal.x - wnormal.y * wnormal.y) +
                               c3 * ambientProbe[6] * wnormal.z * wnormal.z +
                               c4 * ambientProbe[0] -
                               c5 * ambientProbe[6] +
                               2.0 * c1 * ambientProbe[4] * wnormal.x * wnormal.y +
                               2.0 * c1 * ambientProbe[7] * wnormal.x * wnormal.z +
                               2.0 * c1 * ambientProbe[5] * wnormal.y * wnormal.z +
                               2.0 * c2 * ambientProbe[3] * wnormal.x +
                               2.0 * c2 * ambientProbe[1] * wnormal.y +
                               2.0 * c2 * ambientProbe[2] * wnormal.z);
        #else
            ambientDiffuse = vec3(1);
        #endif

        // Multiply the ambient level by the exposure scale.  I don't know if
        // this makes much sense physically, but it works to only apply
        // exposure scaling onto materials that use lighting.
        //#ifdef HDR
        //    ambientDiffuse *= p3d_ExposureScale;
        //#endif

        // Now factor in local light sources
        for (int i = 0; i < NUM_LIGHTS; i++)
        {
            params.lColor = p3d_LightSource[i].color;
            bool isDirectional = p3d_LightSource[i].color.w == 1.0;
            bool isSpot = p3d_LightSource[i].direction.w == 1.0;
            bool isPoint = (!isDirectional && !isSpot);
            params.lPos = p3d_LightSource[i].position;
            params.lDir = normalize(p3d_LightSource[i].direction);
            params.lAtten = vec4(p3d_LightSource[i].attenuation, 0.0);
            params.lSpotParams = p3d_LightSource[i].spotParams;
            #if HAS_SHADOWED_LIGHT
                bool hasShadows = int(p3d_LightSource[i].hasShadows) == 1;
            #endif

            if (isDirectional)
            {
                GetDirectionalLight(params
                                    #ifdef HAS_SHADOW_SUNLIGHT
                                        , p3d_CascadeShadowMap, l_pssmCoords,
                                        p3d_CascadeMVPs, wspos_view.xyz,
                                        l_worldPosition.xyz
                                    #endif // HAS_SHADOW_SUNLIGHT
                );
            }
            else if (isPoint)
            {
                GetPointLight(params
                #ifdef HAS_SHADOWED_POINT_LIGHT
                    , hasShadows, p3d_LightSource[i].shadowMapCube, l_shadowCoords
                #endif
                );
            }
            else if (isSpot)
            {

                #ifdef HAS_SHADOWED_SPOTLIGHT
                    vec4 coords = p3d_LightSource[i].shadowViewMatrix * vec4(l_eyePosition.xyz, 1.0);
                    coords.xyz = coords.xyz / coords.w;
                #endif

                GetSpotlight(params
                #ifdef HAS_SHADOWED_SPOTLIGHT
                    , hasShadows, p3d_LightSource[i].shadowMap2D, coords
                #endif
                );
            }
        }

        vec3 totalRadiance = max(vec3(0), params.totalRadiance);

    #else // LIGHTING

        // No direct lighting.  Just give it the ambient if we have it.
        #ifdef AMBIENT_LIGHT
            vec3 ambientDiffuse = p3d_LightModel.ambient.rgb;
        #else
            // No direct or ambient lighting.  Make it fullbright.
            vec3 ambientDiffuse = vec3(1.0);
        #endif
        vec3 totalRadiance = vec3(0);

    #endif // LIGHTING

    vec3 specularLighting = vec3(0);

    #if defined(RIMLIGHT) && defined(LIGHTING)
        // Dedicated rim lighting for this pixel,
        // adds onto final lighting, uses ambient light as basis
        DedicatedRimTerm(specularLighting, l_worldNormal.xyz,
                         l_worldEyeToVert.xyz, ambientDiffuse,
                         rimlightParams.x, rimlightParams.y);
    #endif

    // Modulate with albedo
    ambientDiffuse.rgb *= albedo.rgb;
    #ifdef HAS_LIGHTMAP
        // Modulate by lightmap.
        ambientDiffuse.rgb *= textureBicubic(lightmapSampler, l_texcoordLightmap).rgb;
    #endif
    #ifdef STATIC_PROP_LIGHTING
        ambientDiffuse.rgb *= l_staticVertexLighting;
    #endif
    ambientDiffuse.rgb *= ao;

	vec3 F = Fresnel_Schlick(specularColor, NdotV);

    //#ifdef LIGHTING
        #if defined(ENVMAP) || defined(PLANAR_REFLECTION)

            //vec3 kD = mix(vec3(1.0) - F, vec3(0.0), armeParams.z);

            #if !defined(ROUGHNESS_MAP) && !defined(GLOSS_MAP)
                perceptualRoughness = 0.0;
            #endif

            #ifdef ENVMAP
                vec3 spec = SampleCubeMapLod(l_worldEyeToVert.xyz,
                                            finalWorldNormal,
                                            envmapSampler, perceptualRoughness).rgb;
            #elif defined(PLANAR_REFLECTION)
                vec2 reflCoords = l_texcoordReflection.xy / l_texcoordReflection.w;
                vec3 spec = texture(reflectionSampler, reflCoords).rgb;
            #endif

            // TODO: use a BRDF lookup texture in SHADERQUALITY_MEDIUM
            #if SHADER_QUALITY > SHADERQUALITY_LOW
                //vec2 specularBRDF = texture(brdfLut, vec2(NdotV, perceptualRoughness)).xy;
                //vec3 brdf = EnvironmentBRDF(armeParams.y*armeParams.y, NdotV, F);
                //vec3 iblspec = (specularColor * brdf.x + brdf.y) * spec;
                //vec3 iblspec = (specularColor * specularBRDF.x + specularBRDF.y) * spec;
                vec3 iblspec = spec * envBRDFApprox(specularColor, perceptualRoughness, NdotV);
            #else
                vec3 iblspec = spec * F * specularColor;
            #endif

            specularLighting += iblspec * specularScale;
        #endif
    //#endif

    vec3 totalAmbient = ambientDiffuse + specularLighting;
    vec3 totalLight = totalAmbient + totalRadiance;
    vec3 color = totalLight;

    #ifdef SELFILLUM
        color += selfillumTint * albedo.rgb * emission;
    #endif

    outputColor = vec4(color, albedo.a);

    #ifdef FOG
		ApplyFog(outputColor, l_eyePosition);
    #endif

    // Done!
	FinalOutput(outputColor);

    #ifdef NEED_AUX_BLOOM
        #ifndef NO_BLOOM
            o_aux_bloom = outputColor;
        #else
            o_aux_bloom = vec4(0, 0, 0, outputColor.a);
        #endif
    #endif
}
