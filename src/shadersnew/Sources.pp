#define DIR_TYPE models

#begin install_sho
  #define SOURCES \
    basic.vert.glsl basic.frag.glsl \
    csmdepth.vert.glsl csmdepth.frag.glsl \
    depth.vert.glsl depth.frag.glsl \
    eyes.vert.glsl eyes.frag.glsl \
    source_lightmapped.vert.glsl source_lightmapped.frag.glsl \
    source_sky.vert.glsl source_sky.frag.glsl \
    source_vlg.vert.glsl source_vlg.frag.glsl \
    spriteParticle.vert.glsl spriteParticle.geom.glsl spriteParticle.frag.glsl \
    two_texture.vert.glsl two_texture.frag.glsl

#end install_sho
