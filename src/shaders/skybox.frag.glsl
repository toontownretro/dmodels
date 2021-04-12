#version 330

#extension GL_GOOGLE_include_directive : enable
#include "shaders/common_frag.inc.glsl"

in vec3 l_worldEyeToVert;
uniform samplerCube skyboxSampler;

in vec4 l_color;

out vec4 outputColor;

void main()
{
    outputColor = texture(skyboxSampler, normalize(l_worldEyeToVert)) * l_color;
	FinalOutput(outputColor);
}
