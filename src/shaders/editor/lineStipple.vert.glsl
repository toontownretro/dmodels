#version 330

uniform mat4 p3d_ModelViewProjectionMatrix;
in vec4 p3d_Vertex;
in vec4 p3d_Color;
out vec4 vtx_color;

void main()
{
        gl_Position = p3d_ModelViewProjectionMatrix * p3d_Vertex;
        vtx_color = p3d_Color;
}
