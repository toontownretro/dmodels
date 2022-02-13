#version 330

in vec2 l_texcoord;

out vec4 o_color;

uniform sampler2DArray cascadeSampler;

void main()
{
    // let's just look at the first cascade which will see everything
    float sample = texture(cascadeSampler, vec3(l_texcoord, 0)).x;
    o_color = vec4(vec3(sample), 1.0);
}
