#ifndef COMMON_ANIMATION_VERT_INC_GLSL
#define COMMON_ANIMATION_VERT_INC_GLSL

#if defined(HARDWARE_SKINNING) && NUM_TRANSFORMS > 0
  #define HAS_HARDWARE_SKINNING 1
#else
  #define HAS_HARDWARE_SKINNING 0
#endif

#if HAS_HARDWARE_SKINNING
  uniform mat4 p3d_TransformTable[NUM_TRANSFORMS];
  in vec4 transform_weight;
  #ifdef INDEXED_TRANSFORMS
    in uvec4 transform_index;
  #endif
#endif

void DoHardwareAnimation(inout vec4 finalVertex, inout vec3 finalNormal, vec4 vertexPos, vec3 normal)
{
  #if HAS_HARDWARE_SKINNING

    #ifndef INDEXED_TRANSFORMS
      const uvec4 transform_index = uvec4(0, 1, 2, 3);
    #endif

    mat4 matrix = p3d_TransformTable[transform_index.x] * transform_weight.x
    #if NUM_TRANSFORMS > 1
      + p3d_TransformTable[transform_index.y] * transform_weight.y
    #endif
    #if NUM_TRANSFORMS > 2
      + p3d_TransformTable[transform_index.z] * transform_weight.z
    #endif
    #if NUM_TRANSFORMS > 3
      + p3d_TransformTable[transform_index.w] * transform_weight.w
    #endif
    ;

    finalVertex = matrix * vertexPos;
    finalNormal = mat3(matrix) * normal;

  #endif
}

#endif // COMMON_ANIMATION_VERT_INC_GLSL
