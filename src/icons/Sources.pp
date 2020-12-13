#define DIR_TYPE models
#define INSTALL_TO icons

#define fltfiles $[wildcard *.flt]
#begin flt_egg
  #define SOURCES $[fltfiles]
#end flt_egg

#define mayafiles $[wildcard *.mb]
#begin maya_egg
  #define SOURCES $[mayafiles]
#end maya_egg

#define eggfiles $[wildcard *.egg]
#begin egg
  #define SOURCES $[eggfiles]
#end egg

#begin install_icons
  #define SOURCES \
      folder.gif minusnode.gif openfolder.gif plusnode.gif python.gif \
      sphere2.gif tk.gif dot_black.gif dot_blue.gif dot_green.gif \
      dot_red.gif dot_white.gif

  // Foundry icons and images
  #define SOURCES $[SOURCES] \
      editor-block.png editor-close.png editor-crosshair.png editor-dec-grid.png \
      editor-dna.png editor-entity.png editor-face-edit.png editor-grid-2d.png \
      editor-grid-3d.png editor-grid-snap.png editor-inc-grid.png editor-move-arrow.png \
      editor-move.png editor-redo.png editor-rotate.png editor-save.png editor-scale.png \
      editor-select-faces.png editor-select-groups.png editor-select-objects.png \
      editor-select-verts.png editor-select.png editor-slice.png editor-undo.png \
      foundry-splash.png foundry.ico

#end install_icons

#begin install_egg
  #define SOURCES \
    $[fltfiles:%.flt=%.egg] $[mayafiles:%.mb=%.egg] \
    $[eggfiles]
#end install_egg
