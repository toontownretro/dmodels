#version 330

#pragma combo FOG        0 1
#pragma combo LIGHTMAP   0 1

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common_frag.inc.glsl"
#include "shadersnew/common.inc.glsl"

uniform sampler2D baseTexture;
uniform sampler2D baseTexture2;

in vec2 l_texcoord;
in vec2 l_texcoord2;

in vec4 l_vertexColor;

in vec4 l_eyePos;
in vec4 l_worldPos;

#if LIGHTMAP
in vec2 l_texcoordLightmap;
uniform sampler2D lightmapTexture;
#endif // LIGHTMAP

#if FOG
layout(constant_id = 0) const int FOG_MODE = FM_linear;
uniform struct p3d_FogParameters {
  vec4 color;
  float density;
  float end;
  float scale; // 1.0 / (end - start)
} p3d_Fog;
#endif // FOG

out vec4 outputColor;

void
main() {
  outputColor = texture(baseTexture, l_texcoord) *
                texture(baseTexture2, l_texcoord2) *
                l_vertexColor;
#if LIGHTMAP
  outputColor.rgb *= textureBicubic(lightmapTexture, l_texcoordLightmap).rgb;
#endif

#if FOG
  outputColor.rgb = do_fog(outputColor.rgb, l_eyePos.xyz, p3d_Fog.color.rgb,
                           p3d_Fog.density, p3d_Fog.end, p3d_Fog.scale,
                           FOG_MODE);
#endif // FOG
}
