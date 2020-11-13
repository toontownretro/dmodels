#define DIR_TYPE models
#define INSTALL_TO maps

// Converts a set of source images to .txo textures and installs them.
#begin install_txo
  #define SOURCES \
    test1.tga test2.tga test3.tga
  // These are the options we would like to pass to make-txo for each source
  // image.
  #define TXO_OPTS -dxt5 -srgb -mipmap -trilinear
#end install_txo

#begin install_txo
  // This indicates that all of our source images should be passed to a single
  // make-txo invocation.  This creates a single .txo with multiple slices, one
  // slice for each source image.
  #define SINGLE 1

  #define SOURCES \
    face1.tga face2.tga face3.tga face4.tga face5.tga face6.tga
  #define TXO_OPTS -dxt5 -srgb -mipmap -trilinear -cubemap

  // A single .txo created from multiple source images requires an explicit
  // output target, because we can't correctly infer what it should be.
  #define TARGET cubemap.txo
#end install_txo
