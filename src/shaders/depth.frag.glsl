#version 330

/**
 * @file depth.frag.glsl
 * @author lachbr
 * @date 2020-12-16
 */

in vec3 l_texcoord_alpha;

#ifdef NEED_WORLD_POSITION
in vec4 l_worldPosition;
#endif

#if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
uniform vec4 p3d_WorldClipPlane[NUM_CLIP_PLANES];
#endif

#ifdef BASETEXTURE
uniform sampler2D baseTextureSampler;
#endif

void main() {
  // Clipping first!
  #if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
    for (int i = 0; i < NUM_CLIP_PLANES; i++) {
      if (dot(p3d_WorldClipPlane[i], l_worldPosition) < 0) {
        // pixel outside of clip plane interiors
        discard;
      }
    }
  #endif

  #if defined(TRANSPARENT) || defined(ALPHA_TEST)
    #ifdef BASETEXTURE
      float alpha = texture(baseTextureSampler, l_texcoord_alpha.xy).a;
      alpha *= l_texcoord_alpha.z;
    #else
      float alpha = l_texcoord_alpha.z;
    #endif

    if (alpha < 0.5) {
      discard;
    }
  #endif
}
