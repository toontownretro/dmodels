#ifndef COMMON_VERT_INC_GLSL
#define COMMON_VERT_INC_GLSL

/**
 * Transforms the vertex position by the joints that
 * influence the vertex.  Maximum of four joints supported.
 */
void
do_skinning(in vec4 vertex_pos,
            in vec3 vertex_normal,
            in vec3 vertex_tangent,
            in vec3 vertex_binormal,

            in mat4 transforms[120],
            in vec4 weights,
            in uvec4 indices,

            out vec4 animated_vertex,
            out vec3 animated_normal,
            out vec3 animated_tangent,
            out vec3 animated_binormal) {

  mat4 matrix = transforms[indices.x] * weights.x +
                transforms[indices.y] * weights.y +
                transforms[indices.z] * weights.z +
                transforms[indices.w] * weights.w;
  animated_vertex = matrix * vertex_pos;
  animated_normal = mat3(matrix) * vertex_normal;
  animated_tangent = mat3(matrix) * vertex_tangent;
  animated_binormal = mat3(matrix) * vertex_binormal;
}

/**
 * Transforms the vertex position by the joints that influence the vertex.
 *
 * This version takes two vec4s for indices and weights, to support up to 8
 * joints influencing a single vertex.  There are some Toontown models with
 * vertices assigned to more than 4 joints.
 */
void
do_skinning8(in vec4 vertex_pos,
             in vec3 vertex_normal,
             in vec3 vertex_tangent,
             in vec3 vertex_binormal,

             in mat4 transforms[120],
             in vec4 weights0,
             in vec4 weights1,
             in uvec4 indices0,
             in uvec4 indices1,

             out vec4 animated_vertex,
             out vec3 animated_normal,
             out vec3 animated_tangent,
             out vec3 animated_binormal) {

  mat4 matrix = transforms[indices0.x] * weights0.x +
                transforms[indices0.y] * weights0.y +
                transforms[indices0.z] * weights0.z +
                transforms[indices0.w] * weights0.w +
                transforms[indices1.x] * weights1.x +
                transforms[indices1.y] * weights1.y +
                transforms[indices1.z] * weights1.z +
                transforms[indices1.w] * weights1.w;
  animated_vertex = matrix * vertex_pos;
  animated_normal = mat3(matrix) * vertex_normal;
  animated_tangent = mat3(matrix) * vertex_tangent;
  animated_binormal = mat3(matrix) * vertex_binormal;
}

#endif // COMMON_VERT_INC_GLSL
