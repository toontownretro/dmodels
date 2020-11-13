#version 330

/**
 * @file csmdepth.frag.glsl
 * @author lachbr
 * @date 2020-10-30
 */

in vec3 g_texcoord_alpha;
in vec4 g_worldPosition;

#if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
uniform vec4 p3d_WorldClipPlane[NUM_CLIP_PLANES];
#endif

#ifdef BASETEXTURE
uniform sampler2D baseTextureSampler;
#endif

out vec4 p3d_FragColor;

void main() {
  // Clipping first!
  #if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
    for (int i = 0; i < NUM_CLIP_PLANES; i++) {
      if (dot(p3d_WorldClipPlane[i], g_worldPosition) < 0) {
        // pixel outside of clip plane interiors
        discard;
      }
    }
  #endif

  #if defined(TRANSPARENT) || defined(ALPHA_TEST)
    #ifdef BASETEXTURE
      float alpha = texture(baseTextureSampler, g_texcoord_alpha.xy).a;
      alpha *= g_texcoord_alpha.z;
    #else
      float alpha = g_texcoord_alpha.z;
    #endif

    if (alpha < 0.5) {
      discard;
    }
  #endif

  p3d_FragColor = vec4(1.0);
}
