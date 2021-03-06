#version 330

in vec2 l_texcoord;

out vec4 o_color;

uniform sampler2DArray cascadeSampler;

void main()
{
    // let's just look at the first cascade which will see everything
    o_color = vec4(vec3(texture(cascadeSampler, vec4(l_texcoord, 0, 1.0))), 1.0);
}
