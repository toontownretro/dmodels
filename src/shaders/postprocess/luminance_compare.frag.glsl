#version 330

in vec2 l_texcoord;

uniform sampler2D sceneColorSampler;
uniform vec2 luminanceMinMax;
uniform ivec2 bucketIndex_numBuckets;

#define bucketIndex (bucketIndex_numBuckets.x)
#define numBuckets (bucketIndex_numBuckets.y)

out vec4 outputColor;

const vec3 luminance_weights = vec3(0.2126, 0.7152, 0.0722);

void main()
{
    vec3 color = texture(sceneColorSampler, l_texcoord).rgb;
    float luminance = dot(color, luminance_weights);

    // If it's the last bucket and the luminance is greater than the max of the
    // last bucket, put it in there anyways.
    if ((luminance >= luminanceMinMax.x && luminance < luminanceMinMax.y) ||
        (bucketIndex == (numBuckets - 1) && luminance >= luminanceMinMax.y))
    {
        outputColor = vec4(1, 0, 0, 0);
        return;
    }

    outputColor = vec4(0, 0, 0, 0);

    // Pixel doesn't fall in specified luminance range.
    discard;
}
