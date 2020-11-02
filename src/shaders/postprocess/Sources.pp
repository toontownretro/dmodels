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
    hbao.frag.glsl \
    luminance_compare.frag.glsl \
    luminance_compare.vert.glsl \
    motion_blur.frag.glsl \
    motion_blur.vert.glsl \
    ssao.frag.glsl \
    ssr.vert.glsl \
    ssr_reflection.frag.glsl
#end install_shader
