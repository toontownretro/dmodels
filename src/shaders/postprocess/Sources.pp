#define DIR_TYPE models
#define INSTALL_TO shaders/postprocess

#begin install_shader
  #define SOURCES \
    apply_bloom.frag.glsl \
    apply_exposure.frag.glsl \
    base.vert.glsl \
    bloom_downsample.frag.glsl \
    bloom_upsample.frag.glsl \
    blur.frag.glsl \
    blur.vert.glsl \
    build_histogram.compute.glsl \
    calc_luminance.compute.glsl \
    downsample.frag.glsl \
    downsample.vert.glsl \
    extract_bright_spots.frag.glsl \
    final_output.frag.glsl \
    freeze_frame.frag.glsl \
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
    remove_fireflies.frag.glsl \
    ssao.frag.glsl \
    ssr_reflection.frag.glsl \
    ssr.vert.glsl \
    tonemap_aces.frag.glsl \
    tonemap_uncharted_2.frag.glsl \
    tonemap_urchima.frag.glsl \
    weighted_blur.frag.glsl \
    weighted_blur.vert.glsl
#end install_shader
