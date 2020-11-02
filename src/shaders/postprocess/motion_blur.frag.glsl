#version 330

in vec2 l_texcoord;

uniform sampler2D texSampler;

uniform vec4 motionBlurParams[1];
uniform vec4 consts[1];

#define g_globalBlurVector motionBlurParams[0].xy
#define g_fallingMotionIntensity motionBlurParams[0].z
#define g_rollBlurIntensity motionBlurParams[0].w
#define g_maxMotionBlur consts[0].x
#define g_quality consts[0].y

out vec4 outputColor;

void main()
{
    // Calculate blur vector
    vec2 fallingMotionBlurVector = ((l_texcoord * 2.0) - 1.0);
    vec2 rollBlurVector = cross(vec3(fallingMotionBlurVector, 0.0), vec3(0, 0, 0)).xy;
    vec2 globalBlurVector = g_globalBlurVector;
    globalBlurVector.y = -globalBlurVector.y;

    float fallingMotionBlurIntensity = -abs(g_fallingMotionIntensity); // Keep samples on screen by keeping vector pointing in
    fallingMotionBlurVector *= dot(fallingMotionBlurVector, fallingMotionBlurVector); // Dampen the effect in the middle of the screen
    fallingMotionBlurVector *= fallingMotionBlurIntensity;

    float rollBlurIntensity = g_rollBlurIntensity;
    rollBlurVector *= rollBlurIntensity;

    vec2 finalBlurVector = globalBlurVector + fallingMotionBlurVector + rollBlurVector;

    // Clamp length of blur vector to unit length
    if (length(finalBlurVector) > g_maxMotionBlur)
    {
        finalBlurVector = normalize(finalBlurVector) * g_maxMotionBlur;
    }

    int numSamples = 1;
    int quality = int(g_quality);

    // Set number of samples
    switch (quality)
    {
    case 0:
        numSamples = 1;
        break;
    case 1:
        numSamples = 7;
        break;
    case 2:
        numSamples = 11;
        break;
    case 3:
        numSamples = 15;
        break;
    default:
        break;
    }

    if (numSamples > 1)
    {
        vec4 color = vec4(0, 0, 0, 0);
        vec2 uvOffset = finalBlurVector / (numSamples - 1);
        for (int x = 0; x < numSamples; x++)
        {
            // Calculate uv
            vec2 uvTmp = l_texcoord + (uvOffset * x);

            // Sample pixel
            color += (1.0 / numSamples) * texture(texSampler, uvTmp); // Evenly weight all samples
        }

        outputColor = vec4(color.rgb, 1.0);
    }
    else
    {
        outputColor = texture(texSampler, l_texcoord);
    }

}
