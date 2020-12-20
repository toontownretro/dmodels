#version 330

/**
 * @file csmdepth.geom.glsl
 * @author lachbr
 * @date 2020-10-30
 */

layout(triangles) in;
layout(triangle_strip, max_vertices = MAX_VERTICES) out;

in vec3 v_texcoord_alpha[];
in int v_instanceID[];
#ifdef NEED_WORLD_POSITION
in vec4 v_worldPosition[];
out vec4 g_worldPosition;
#endif

out vec3 g_texcoord_alpha;

void main() {
  // Emit the vertices to the correct cascade layer.
  for (int i = 0; i < gl_in.length(); i++) {
    gl_Position = gl_in[i].gl_Position;
    gl_Layer = v_instanceID[i];
    g_texcoord_alpha = v_texcoord_alpha[i];
    #ifdef NEED_WORLD_POSITION
      g_worldPosition = v_worldPosition[i];
    #endif
    EmitVertex();
  }
  EndPrimitive();
}
