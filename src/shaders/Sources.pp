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
    csmdepth.frag.glsl \
    csmdepth.geom.glsl \
    csmdepth.vert.glsl \
    debug_csm.frag.glsl \
    debug_csm.vert.glsl \
    depth.frag.glsl \
    depth.vert.glsl \
    eyes.frag.glsl \
    eyes.vert.glsl \
    lightmappedGeneric_PBR.frag.glsl \
    lightmappedGeneric_PBR.vert.glsl \
    skybox.frag.glsl \
    skybox.vert.glsl \
    unlitNoMat.frag.glsl \
    unlitNoMat.vert.glsl \
    vertexLitGeneric_PBR.frag.glsl \
    vertexLitGeneric_PBR.vert.glsl
#end install_shader
