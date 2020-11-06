#define DIR_TYPE models
#define INSTALL_TO shaders/postprocess

#begin install_shader
  #define SOURCES \
    base.vert.glsl \
    blur.frag.glsl \
    blur.vert.glsl \
    downsample.frag.glsl \
    downsample.vert.glsl \
    fxaa.frag.glsl \
    fxaa.vert.glsl \
    hbao_old.frag.glsl \
    hbao.frag.glsl \
    hbao.vert.glsl \
    hbao2.frag.glsl \
    luminance_compare.frag.glsl \
    luminance_compare.vert.glsl \
    motion_blur.frag.glsl \
    motion_blur.vert.glsl \
    ssao.frag.glsl \
    ssr_reflection.frag.glsl \
    ssr.vert.glsl \
    weighted_blur.frag.glsl \
    weighted_blur.vert.glsl
#end install_shader
