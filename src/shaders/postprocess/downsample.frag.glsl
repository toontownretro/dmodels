#version 330

in vec2 l_coordTap0;
in vec2 l_coordTap1;
in vec2 l_coordTap2;
in vec2 l_coordTap3;

uniform vec2 camSettings[1];
#define camExposure (camSettings[0].x)
#define camMaxLuminance (camSettings[0].y)

uniform sampler2D fbColorSampler;
uniform vec4 params;

out vec4 outputColor;

const vec3 Y = vec3(0.2125, 0.7154, 0.0721);

vec4 Shape(vec2 uv)
{
    vec4 pixel = texture(fbColorSampler, uv);

    // Get luminance of pixel multiplied by exposure.
    float lum = dot(pixel.xyz, Y);

    // Induce bloom if the calculated luminance is greater than the max
    // luminance of the camera.
    float bloomAmount = max(0, lum - (camMaxLuminance * 0.5));
    pixel.rgb = pixel.rgb * bloomAmount;

    return pixel;
}

void main()
{
    vec4 s0, s1, s2, s3;

    // Sample 4 taps
    s0 = Shape(l_coordTap0);
    s1 = Shape(l_coordTap1);
    s2 = Shape(l_coordTap2);
    s3 = Shape(l_coordTap3);

    outputColor = (s0 + s1 + s2 + s3) * 0.25;
}
