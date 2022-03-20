#ifndef COMMON_SHADOWS_FRAG_INC_GLSL
#define COMMON_SHADOWS_FRAG_INC_GLSL

int FindCascade(vec4 shadowCoords[4], inout vec3 proj, int numCascades)
{
	for (int i = 0; i < 4 && i < numCascades; i++)
	{
		proj = shadowCoords[i].xyz;
		if (proj.x >= 0.0 && proj.x <= 1.0 && proj.y >= 0.0 && proj.y <= 1.0)
		{
			return i;
		}
	}
}

void GetSunShadow(inout float lshad, sampler2DArrayShadow shadowSampler, vec4 shadowCoords[4],
                  float NdotL, int numCascades)
{
    if (NdotL <= 0.0) {
        lshad = 1.0;
        return;
    }

    lshad = 0.0;

	vec3 proj = vec3(0);
	int cascade = FindCascade(shadowCoords, proj, numCascades);

  vec4 coords = vec4(proj.xy, cascade, proj.z);

  ivec3 texSize = textureSize(shadowSampler, 0);
  vec2 filterSize = vec2(1.0 / float(texSize.x), 1.0 / float(texSize.y));

  switch (cascade) {
  case 0:
  case 1:
      {
          // 9 taps. PCF3x3Box.
          vec4 oneTaps = vec4(0);
          oneTaps.x = texture(shadowSampler, coords + vec4( filterSize.x,  filterSize.y, 0, 0));
          oneTaps.y = texture(shadowSampler, coords + vec4(-filterSize.x,  filterSize.y, 0, 0));
          oneTaps.z = texture(shadowSampler, coords + vec4( filterSize.x, -filterSize.y, 0, 0));
          oneTaps.w = texture(shadowSampler, coords + vec4(-filterSize.x, -filterSize.y, 0, 0));
          float flOneTaps = dot(oneTaps, vec4(1.0 / 9.0));

          vec4 twoTaps = vec4(0);
          twoTaps.x = texture(shadowSampler, coords + vec4( filterSize.x,  0, 0, 0));
          twoTaps.y = texture(shadowSampler, coords + vec4(-filterSize.x,  0, 0, 0));
          twoTaps.z = texture(shadowSampler, coords + vec4( 0,  -filterSize.y, 0, 0));
          twoTaps.w = texture(shadowSampler, coords + vec4( 0,  filterSize.y, 0, 0));
          float flTwoTaps = dot(twoTaps, vec4(1.0 / 9.0));

          float flCenterTap = texture(shadowSampler, coords) * (1.0 / 9.0);

          // Sum all 9 taps.
          lshad = flOneTaps + flTwoTaps + flCenterTap;
      }
      break;
  case 2:
      {
          // 4 taps.
          vec4 oneTaps = vec4(0);
          oneTaps.x = texture(shadowSampler, coords + vec4( filterSize.x,  filterSize.y, 0, 0));
          oneTaps.y = texture(shadowSampler, coords + vec4(-filterSize.x,  filterSize.y, 0, 0));
          oneTaps.z = texture(shadowSampler, coords + vec4( filterSize.x, -filterSize.y, 0, 0));
          oneTaps.w = texture(shadowSampler, coords + vec4(-filterSize.x, -filterSize.y, 0, 0));
          lshad = dot(oneTaps, vec4(0.25));
      }
      break;
  case 3:
  default:
      {
          // 1 tap.
          lshad = texture(shadowSampler, coords);
      }
      break;
  }
}

#endif // COMMON_SHADOWS_FRAG_INC_GLSL
