#ifndef COMMON_CLUSTERED_LIGHTING_INC_GLSL
#define COMMON_CLUSTERED_LIGHTING_INC_GLSL

#extension GL_ARB_shading_language_420pack : enable

#define MAX_LIGHTS_PER_CLUSTER 64
#define TEXELS_PER_CLUSTER_LIGHT 5

#define LIGHT_TYPE_POINT 0
#define LIGHT_TYPE_SPOT 1
#define LIGHT_TYPE_DIRECTIONAL 2

struct ClusterLightData {
  int type;

  vec3 color;

  vec3 pos;
  vec3 direction;

  // Attenuation.
  float constant_atten;
  float linear_atten;
  float quadratic_atten;
  float atten_radius;

  // Spotlight params.
  float spot_exponent;
  float spot_stopdot;
  float spot_stopdot2;
  float spot_oodot;
};

/**
 *
 */
void
priv_fetch_cluster_light(int index, samplerBuffer buf, out ClusterLightData light) {
  int start = index * TEXELS_PER_CLUSTER_LIGHT;
  vec4 data;

  data = texelFetch(buf, start);
  light.type = int(data.x);
  light.constant_atten = data.y;
  light.linear_atten = data.z;
  light.quadratic_atten = data.w;

  data = texelFetch(buf, start + 1);
  light.color = data.xyz;
  light.atten_radius = data.w;

  data = texelFetch(buf, start + 2);
  light.pos = data.xyz;

  data = texelFetch(buf, start + 3);
  light.direction = data.xyz;

  data = texelFetch(buf, start + 4);
  light.spot_exponent = data.x;
  light.spot_stopdot = data.y;
  light.spot_stopdot2 = data.z;
  light.spot_oodot = data.w;
}

/**
 *
 */
void
fetch_cluster_light(int index, samplerBuffer staticLights, samplerBuffer dynamicLights,
                    out ClusterLightData light) {
  if (index < 0) {
    priv_fetch_cluster_light(~index, dynamicLights, light);
  } else {
    priv_fetch_cluster_light(index - 1, staticLights, light);
  }
}

/**
 *
 */
bool is_dynamic_light_index(int index) {
  return index < 0;
}

/**
 *
 */
bool is_static_light_index(int index) {
  return index > 0;
}

/**
 *
 */
float
linearDepth(float depthSample) {
  float depthRange = 2.0 * depthSample - 1.0;
  float zNear = p3d_LensNearFar.x;
  float zFar = p3d_LensNearFar.y;
  float linear = 2.0 * zNear * zFar / (zFar + zNear - depthRange * (zFar - zNear));
  return linear;
}

#define OPEN_ITERATE_CLUSTERED_LIGHTS() \
  { \
      uvec3 tiles; \
      tiles.x = uint(floor((gl_FragCoord.x / p3d_WindowSize.x) * p3d_LightLensDiv.x)); \
      tiles.y = uint(floor((gl_FragCoord.y / p3d_WindowSize.y) * p3d_LightLensDiv.y)); \
      tiles.z = uint(max(log2(linearDepth(gl_FragCoord.z)) * p3d_LightLensZScaleBias.x + p3d_LightLensZScaleBias.y, 0.0)); \
      uint tileIndex = uint(tiles.x + \
                      p3d_LightLensDiv.x * tiles.y + \
                      (p3d_LightLensDiv.x * p3d_LightLensDiv.y) * tiles.z); \
      int ofs = 0; \
      int light_index = int(texelFetch(p3d_LightListBuffer, int(tileIndex) * MAX_LIGHTS_PER_CLUSTER).x); \
      ClusterLightData light; \
      while (ofs < MAX_LIGHTS_PER_CLUSTER && light_index != 0) {

#define CLOSE_ITERATE_CLUSTERED_LIGHTS() \
        ++ofs; \
        light_index = int(texelFetch(p3d_LightListBuffer, int(tileIndex) * MAX_LIGHTS_PER_CLUSTER + ofs).x); \
      } \
  }

#endif // COMMON_CLUSTERED_LIGHTING_INC_GLSL
