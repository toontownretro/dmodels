#ifndef COMMON_VERT_INC_GLSL
#define COMMON_VERT_INC_GLSL

/**
 * Transforms the vertex position by the joints that
 * influence the vertex.  Maximum of four joints supported.
 */
void
do_skinning(in vec4 vertex_pos, in vec3 vertex_normal, in mat4 transforms[120], in vec4 weights,
            in uvec4 indices, bool do_normal, out vec4 animated_vertex, out vec3 animated_normal) {
  mat4 matrix = transforms[indices.x] * weights.x +
                transforms[indices.y] * weights.y +
                transforms[indices.z] * weights.z +
                transforms[indices.w] * weights.w;
  animated_vertex = matrix * vertex_pos;
  if (do_normal) {
    animated_normal = mat3(matrix) * vertex_normal;
  }
}

#endif // COMMON_VERT_INC_GLSL
