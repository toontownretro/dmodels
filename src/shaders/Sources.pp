#define DIR_TYPE models
#define INSTALL_TO shaders

#begin install_shader
  #define SOURCES \
    common_animation_vert.inc.glsl \
    common_brdf_frag.inc.glsl \
    common_fog_frag.inc.glsl \
    common_frag.inc.glsl \
    common_lighting_frag.inc.glsl \
    common_sequences.inc.glsl \
    common_shadows_frag.inc.glsl \
    common_shadows_vert.inc.glsl \
    common_vert.inc.glsl \
    common.inc.glsl \
    compress_bc6h.compute.glsl \
    csmdepth.frag.glsl \
    csmdepth.geom.glsl \
    csmdepth.vert.glsl \
    cubemap_filter.compute.glsl \
    debug_csm.frag.glsl \
    debug_csm.vert.glsl \
    depth.frag.glsl \
    depth.vert.glsl \
    eyes.frag.glsl \
    eyes.vert.glsl \
    lightmappedGeneric_PBR.frag.glsl \
    lightmappedGeneric_PBR.vert.glsl \
    lm_buffers.inc.glsl lm_compute.inc.glsl \
    lm_direct.compute.glsl lm_indirect.compute.glsl lm_unocclude.compute.glsl \
    lm_raster.frag.glsl lm_raster.vert.glsl \
    lm_probes.compute.glsl \
    lm_dilate.compute.glsl \
    lm_vtx_direct.compute.glsl \
    lm_vtx_indirect.compute.glsl \
    lm_vtx_raster.vert.glsl lm_vtx_raster.frag.glsl \
    skybox.frag.glsl \
    skybox.vert.glsl \
    source_vlg.vert.glsl source_vlg.frag.glsl source_vlg_orig.frag.glsl \
    spriteParticle.vert.glsl spriteParticle.geom.glsl spriteParticle.frag.glsl \
    unlitNoMat.frag.glsl \
    unlitNoMat.vert.glsl \
    vertexLitGeneric_PBR.frag.glsl \
    vertexLitGeneric_PBR.vert.glsl \
    source_sky.vert.glsl source_sky.frag.glsl
#end install_shader
