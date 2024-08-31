#ifndef COMMON_SHADOWS_FRAG_INC_GLSL
#define COMMON_SHADOWS_FRAG_INC_GLSL

vec2 shadowPoissonDisk_16[16] = vec2[](
    vec2( -0.94201624, -0.39906216 ),
    vec2( 0.94558609, -0.76890725 ),
    vec2( -0.094184101, -0.92938870 ),
    vec2( 0.34495938, 0.29387760 ),
    vec2( -0.91588581, 0.45771432 ),
    vec2( -0.81544232, -0.87912464 ),
    vec2( -0.38277543, 0.27676845 ),
    vec2( 0.97484398, 0.75648379 ),
    vec2( 0.44323325, -0.97511554 ),
    vec2( 0.53742981, -0.47373420 ),
    vec2( -0.26496911, -0.41893023 ),
    vec2( 0.79197514, 0.19090188 ),
    vec2( -0.24188840, 0.99706507 ),
    vec2( -0.81409955, 0.91437590 ),
    vec2( 0.19984126, 0.78641367 ),
    vec2( 0.14383161, -0.14100790 )
);

float texShadow(sampler2DArray shadowSampler, vec4 coords) {
  return step(coords.w, texture(shadowSampler, coords.xyz).x);
}

float texShadow(sampler2DArrayShadow shadowSampler, vec4 coords) {
  return texture(shadowSampler, coords).x;
}

float PCSS_DepthToZ(float depth, float near, float far)
{
    return near + ( far - near ) * depth;
}

vec2 PCSS_FindAverageOccluder(sampler2DArray shadowSampler, vec3 shadowCoords, int slice,
                              float lightSize, float lightNear, float lightFar)
{
    ivec3 texSize = textureSize(shadowSampler, 0);
    vec2 texelSize = vec2(1.0 / float(texSize.x), 1.0 / float(texSize.y));

    //float zReceiver = PCSS_DepthToZ(shadowCoords.z, lightNear, lightFar);
    //float searchWidth = lightSize * (zReceiver - lightNear) / zReceiver;

    float sum = 0.0;
    float count = 0.0;

    for (int i = 0; i < 16; ++i)
    {
        vec2 s = shadowCoords.xy + shadowPoissonDisk_16[i] * texelSize.x * lightSize;
        float depth = texture(shadowSampler, vec3(s, slice)).x;
        if (depth < shadowCoords.z) {
            sum += depth;
            ++count;
        }
    }

    return vec2(PCSS_DepthToZ(sum / count, lightNear, lightFar), count);
}

float PCSS_GetFilterRadius(sampler2DArray shadowSampler, vec3 shadowCoords, int slice,
                           float lightSize, float lightNear, float lightFar, float blurRadius)
{
    //shadowCoords.z -= 0.001;
    vec2 occluderInfo = PCSS_FindAverageOccluder(shadowSampler, shadowCoords, slice, lightSize, lightNear, lightFar);
    if (occluderInfo.y == 0.0) {
        return 0.0;
    }
    float occluder = occluderInfo.x;
    float receiver = PCSS_DepthToZ(shadowCoords.z, lightNear, lightFar);
    float penumbraWidth = (receiver - occluder);
    float filterRadius = penumbraWidth * blurRadius;
    return filterRadius;
}

int FindCascade(vec4 shadowCoords[4], inout vec3 proj, int numCascades)
{
	for (int i = 0; i < 4 && i < numCascades; i++)
	{
		proj = shadowCoords[i].xyz;
		if (proj.x >= 0.0 && proj.x <= 1.0 && proj.y >= 0.0 && proj.y <= 1.0 &&
            proj.z >= 0.0 && proj.z <= 1.0)
		{
			return i;
		}
	}
    return -1;
}

float GetShadowRandomOffsetSampling(sampler2DArrayShadow shadowSampler, vec3 shadowCoords, int slice,
                                    sampler3D offsetTex, float blurRadius, float offsetWindowSize,
                                    float offsetFilterSize, vec2 fragCoord)
{
    ivec3 offsetCoord = ivec3(0);
    vec2 f = mod(fragCoord.xy, vec2(offsetWindowSize));
    offsetCoord.yz = ivec2(f);
    float sum = 0.0;
    int samplesDiv2 = int(offsetFilterSize * offsetFilterSize / 2.0);

    ivec3 texSize = textureSize(shadowSampler, 0);
    vec2 texelSize = vec2(1.0 / float(texSize.x), 1.0 / float(texSize.y));

    float depth = 0.0;

    vec2 coords;

    for (int i = 0; i < 4; ++i) {
        offsetCoord.x = i;
        vec4 offsets = texelFetch(offsetTex, offsetCoord, 0) * blurRadius;
        coords = shadowCoords.xy + offsets.rg * texelSize;
        depth = texture(shadowSampler, vec4(coords, slice, shadowCoords.z)).x;
        sum += depth;

        coords = shadowCoords.xy + offsets.ba * texelSize;
        depth = texture(shadowSampler, vec4(coords, slice, shadowCoords.z)).x;
        sum += depth;
    }

    float lshad = sum / 8.0;

    if (lshad != 0.0 && lshad != 1.0) {
        for (int i = 4; i < samplesDiv2; ++i) {
            offsetCoord.x = i;
            vec4 offsets = texelFetch(offsetTex, offsetCoord, 0) * blurRadius;
            coords = shadowCoords.xy + offsets.rg * texelSize;
            depth = texture(shadowSampler, vec4(coords, slice, shadowCoords.z)).x;
            sum += depth;

            coords = shadowCoords.xy + offsets.ba * texelSize;
            depth = texture(shadowSampler, vec4(coords, slice, shadowCoords.z)).x;
            sum += depth;
        }

        lshad = sum / float(samplesDiv2 * 2.0);
    }

    return lshad;
}

void GetSunShadow(inout float lshad, sampler2DArrayShadow shadowSampler, vec4 shadowCoords[4],
                  float NdotL, int numCascades, sampler3D offsetTex, float blurRadius, float offsetWindowSize, float offsetFilterSize, vec2 fragCoord,
                  float lightSize, vec2 lightNearFar[4])
{
    lshad = 0.0;

    vec3 proj = vec3(0);
    int cascade = FindCascade(shadowCoords, proj, numCascades);
    if (cascade < 0) {
        lshad = 1.0;
        return;
    }

    //float bias = max(0.05 * (1.0 - NdotL), 0.005);
    //bias *= 1.0 / (lightNearFar[cascade].y * 0.5);
    //proj.z -= bias;
    //proj.z -= 0.0001;

 #if 1
    ivec3 texSize = textureSize(shadowSampler, 0);
    vec2 filterSize = vec2(1.0 / float(texSize.x), 1.0 / float(texSize.y));
    float bias = max(1.0 - (1.0 - NdotL), 0.0);
    bias += cascade * 0.5;
    proj.z -= 0.0;//bias * max(filterSize.x, filterSize.y);

   // float filterRadius = 4.0;
    //filterRadius =  PCSS_GetFilterRadius(shadowSampler, proj, cascade, lightSize, lightNearFar[cascade].x, lightNearFar[cascade].y, blurRadius);
    //if (filterRadius < 0.0) {
    //    return;
    //}
    float filterRadius = 3.0;
    lshad = GetShadowRandomOffsetSampling(shadowSampler, proj, cascade, offsetTex, filterRadius, offsetWindowSize, offsetFilterSize, fragCoord);
    #endif


#if 0
  ivec3 texSize = textureSize(shadowSampler, 0);
  vec2 filterSize = vec2(1.0 / float(texSize.x), 1.0 / float(texSize.y));
  float bias = 0.0;//max(1.0 - (1.0 - NdotL), 0.0);
  //proj.z -= bias * max(filterSize.x, filterSize.y);
  vec4 coords = vec4(proj.x, proj.y, float(cascade), proj.z);
  switch (cascade) {
  case 0:
  case 1:
  case 2:
  case 3:
  default:
      {
          // 9 taps. PCF3x3Box.
          vec4 oneTaps = vec4(0);
          oneTaps.x = texShadow(shadowSampler, coords + vec4( filterSize.x,  filterSize.y, 0, 0));
          oneTaps.y = texShadow(shadowSampler, coords + vec4(-filterSize.x,  filterSize.y, 0, 0));
          oneTaps.z = texShadow(shadowSampler, coords + vec4( filterSize.x, -filterSize.y, 0, 0));
          oneTaps.w = texShadow(shadowSampler, coords + vec4(-filterSize.x, -filterSize.y, 0, 0));
          float flOneTaps = dot(oneTaps, vec4(1.0 / 9.0));

          vec4 twoTaps = vec4(0);
          twoTaps.x = texShadow(shadowSampler, coords + vec4( filterSize.x,  0, 0, 0));
          twoTaps.y = texShadow(shadowSampler, coords + vec4(-filterSize.x,  0, 0, 0));
          twoTaps.z = texShadow(shadowSampler, coords + vec4( 0,  -filterSize.y, 0, 0));
          twoTaps.w = texShadow(shadowSampler, coords + vec4( 0,  filterSize.y, 0, 0));
          float flTwoTaps = dot(twoTaps, vec4(1.0 / 9.0));

          float flCenterTap = texShadow(shadowSampler, coords) * (1.0 / 9.0);

          // Sum all 9 taps.
          lshad = flOneTaps + flTwoTaps + flCenterTap;
      }
      break;
#if 0
  case 2:
      {
          // 4 taps.
          vec4 oneTaps = vec4(0);
          oneTaps.x = texShadow(shadowSampler, coords + vec4( filterSize.x,  filterSize.y, 0, 0));
          oneTaps.y = texShadow(shadowSampler, coords + vec4(-filterSize.x,  filterSize.y, 0, 0));
          oneTaps.z = texShadow(shadowSampler, coords + vec4( filterSize.x, -filterSize.y, 0, 0));
          oneTaps.w = texShadow(shadowSampler, coords + vec4(-filterSize.x, -filterSize.y, 0, 0));
          lshad = dot(oneTaps, vec4(0.25));
      }
      break;
  case 3:
  default:
      {
          // 1 tap.
          lshad = texShadow(shadowSampler, coords);
      }
      break;
#endif
  }
#endif
}

#endif // COMMON_SHADOWS_FRAG_INC_GLSL
