#version 330

out vec4 o_color;
uniform ivec2 stippleParams; 
in vec4 vtx_color;

void main()
{
        uint pattern = uint(stippleParams.x);
        uint factor = uint(stippleParams.y);
        float line_pos = gl_FragCoord.x + gl_FragCoord.y;
        uint bit = (uint(round(line_pos / factor)) % factor) & 31U;
        if ((pattern & (1U << bit)) == 0U) discard;
        o_color = vtx_color;
}
