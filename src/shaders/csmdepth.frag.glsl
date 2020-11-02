#version 330

/**
 * @file csmdepth.frag.glsl
 * @author lachbr
 * @date 2020-10-30
 */

in vec3 g_texcoord_alpha;

uniform sampler2D p3d_Texture0;

out vec4 p3d_FragColor;

void main() {
  #if defined(TRANSPARENT) || defined(ALPHA_TEST)
    float alpha = texture(p3d_Texture0, g_texcoord_alpha.xy).a;
    alpha *= g_texcoord_alpha.z;

    if (alpha < 0.5) {
      discard;
    }
  #endif

  p3d_FragColor = vec4(1.0);
}
