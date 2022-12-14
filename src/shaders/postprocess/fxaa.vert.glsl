#version 330

//uniform vec2 rcpSize;
uniform mat4 p3d_ModelViewProjectionMatrix;
in vec2 texcoord;
in vec4 p3d_Vertex;
out vec2 uv;
//out vec4 posPos;

//#define subpixelShift (1.0 / 4.0)

void main()
{
	gl_Position = p3d_ModelViewProjectionMatrix * p3d_Vertex;
	uv = texcoord;

	//posPos.xy = texcoord;
	//posPos.zw = texcoord - (rcpSize * (0.5 + subpixelShift));
}
