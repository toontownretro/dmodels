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

uniform sampler2D p3d_Texture0;

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
    float alpha = texture(p3d_Texture0, g_texcoord_alpha.xy).a;
    alpha *= g_texcoord_alpha.z;

    if (alpha < 0.5) {
      discard;
    }
  #endif

  p3d_FragColor = vec4(1.0);
}
