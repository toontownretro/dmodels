#version 330

uniform sampler2D sceneTexture;
uniform vec2 rcpSize;
in vec4 posPos;
out vec4 o_color;

#define FxaaInt2 ivec2
#define FxaaFloat2 vec2

// The FXAA needs to happen in sRGB space.  Our pipeline is entirely
// linear up until we present to the window, so we have to manually
// convert the source texture to sRGB (and the result back to linear).
#define FxaaTexLod0(t, p) pow(textureLod(t, p, 0.0), vec4(vec3(1.0/2.2), 1))
#define FxaaTexOff(t, p, o, r) pow(textureLodOffset(t, p, 0.0, o), vec4(vec3(1.0/2.2), 1))

#define FXAA_REDUCE_MIN   (1.0/128.0)
#define reduceMul   (1.0/8.0)
#define spanMax     8.0

vec3 FxaaPixelShader(
  vec4 posPos, // Output of FxaaVertexShader interpolated across screen.
  sampler2D tex, // Input texture.
  vec2 rcpFrame) // Constant {1.0/frameWidth, 1.0/frameHeight}.
{
/*---------------------------------------------------------*/
    vec3 rgbNW = FxaaTexLod0(tex, posPos.zw).xyz;
    vec3 rgbNE = FxaaTexLod0(tex, posPos.zw + vec2(1,0) * rcpFrame.xy).xyz;
    vec3 rgbSW = FxaaTexLod0(tex, posPos.zw + vec2(0,1) * rcpFrame.xy).xyz;
    vec3 rgbSE = FxaaTexLod0(tex, posPos.zw + vec2(1,1) * rcpFrame.xy).xyz;
    vec3 rgbM  = FxaaTexLod0(tex, posPos.xy).xyz;
/*---------------------------------------------------------*/
    vec3 luma = vec3(0.299, 0.587, 0.114);
    float lumaNW = dot(rgbNW, luma);
    float lumaNE = dot(rgbNE, luma);
    float lumaSW = dot(rgbSW, luma);
    float lumaSE = dot(rgbSE, luma);
    float lumaM  = dot(rgbM,  luma);
/*---------------------------------------------------------*/
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
/*---------------------------------------------------------*/
    vec2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
/*---------------------------------------------------------*/
    float dirReduce = max(
        (lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * reduceMul),
        FXAA_REDUCE_MIN);
    float rcpDirMin = 1.0/(min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(FxaaFloat2( spanMax,  spanMax),
          max(FxaaFloat2(-spanMax, -spanMax),
          dir * rcpDirMin)) * rcpFrame.xy;
/*--------------------------------------------------------*/
    vec3 rgbA = (1.0/2.0) * (
        FxaaTexLod0(tex, posPos.xy + dir * (1.0/3.0 - 0.5)).xyz +
        FxaaTexLod0(tex, posPos.xy + dir * (2.0/3.0 - 0.5)).xyz);
    vec3 rgbB = rgbA * (1.0/2.0) + (1.0/4.0) * (
        FxaaTexLod0(tex, posPos.xy + dir * (0.0/3.0 - 0.5)).xyz +
        FxaaTexLod0(tex, posPos.xy + dir * (3.0/3.0 - 0.5)).xyz);
    float lumaB = dot(rgbB, luma);
    if((lumaB < lumaMin) || (lumaB > lumaMax)) return rgbA;
    return rgbB; }

vec4 PostFX(sampler2D tex, vec2 uv)
{
  vec4 c = vec4(0.0);
  // Convert output back to linear space.
  c.rgb = pow(FxaaPixelShader(posPos, tex, rcpSize), vec3(2.2));
  c.a = textureLod(tex, uv, 0).a;
  return c;
}

void main()
{
  o_color = PostFX(sceneTexture, posPos.xy);
}
