#define DIR_TYPE models
#define INSTALL_TO shaders

#begin install_shader
  #define SOURCES \
    common_sequences.inc.glsl \
    common.inc.glsl \
    compress_bc6h.compute.glsl \
    cubemap_filter.compute.glsl \
    debug_csm.frag.glsl \
    debug_csm.vert.glsl \
    light_probe_vis.vert.glsl light_probe_vis.frag.glsl \
    lm_buffers.inc.glsl lm_compute.inc.glsl \
    lm_direct.compute.glsl lm_indirect.compute.glsl lm_unocclude.compute.glsl \
    lm_raster.frag.glsl lm_raster.vert.glsl \
    lm_probes.compute.glsl \
    lm_dilate.compute.glsl \
    lm_vtx_direct.compute.glsl \
    lm_vtx_indirect.compute.glsl \
    lm_vtx_raster.vert.glsl lm_vtx_raster.frag.glsl

#end install_shader
