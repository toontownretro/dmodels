
struct PCSS_Params {
  sampler2DArray shadowMap;
  vec3 shadowCoords; // x, y, shadow-space depth of frag.
  int cascade; // Z index into array texture.
  float nearPlane; // Near plane.
  int blockerSearchSampleCount;
  float lightWorldSize;
  float lightFrustumWidth;
};
