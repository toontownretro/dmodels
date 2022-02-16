#version 330

/**
 * @file csmdepth.frag.glsl
 * @author lachbr
 * @date 2020-10-30
 */

in vec3 v_texcoord_alpha;

#ifdef NEED_WORLD_POSITION
in vec4 v_worldPosition;
#endif

#if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
uniform vec4 p3d_WorldClipPlane[NUM_CLIP_PLANES];
#endif

#ifdef BASETEXTURE
uniform sampler2D baseTextureSampler;
#endif

in vec2 l_clipPosition;
//flat in int l_instanceID;
flat in vec4 atlasMinMax;

out vec4 p3d_FragColor;

//uniform vec2 p3d_WindowSize;

void main() {
  // Clipping first!
  #if defined(NUM_CLIP_PLANES) && NUM_CLIP_PLANES > 0
    for (int i = 0; i < NUM_CLIP_PLANES; i++) {
      if (dot(p3d_WorldClipPlane[i], v_worldPosition) < 0) {
        // pixel outside of clip plane interiors
        discard;
      }
    }
  #endif

  //vec2 clip = gl_FragCoord.xy / vec2(800.0, 600.0);

  // Clip to cascade atlas region interiors.
  if ((l_clipPosition.x < atlasMinMax.x) ||
      (l_clipPosition.x > atlasMinMax.y) ||
      (l_clipPosition.y < atlasMinMax.z) ||
      (l_clipPosition.y > atlasMinMax.w)) {
    discard;
  }

  #if defined(TRANSPARENT) || defined(ALPHA_TEST)
    #ifdef BASETEXTURE
      float alpha = texture(baseTextureSampler, v_texcoord_alpha.xy).a;
      alpha *= v_texcoord_alpha.z;
    #else
      float alpha = v_texcoord_alpha.z;
    #endif

    if (alpha < 0.5) {
      discard;
    }
  #endif

  p3d_FragColor = vec4(1.0);
}
