#version 330

#pragma combo ANIMATED 0 1
#pragma combo TRAIL 0 1
#pragma combo DIRECT_LIGHT 0 1
#pragma combo AMBIENT_LIGHT 0 2

/**
 * PANDA 3D SOFTWARE
 * Copyright (c) Carnegie Mellon University.  All rights reserved.
 *
 * All use of this software is subject to the terms of the revised BSD
 * license.  You should have received a copy of this license along
 * with this source code in a file named "LICENSE."
 *
 * @file spriteParticle.vert.glsl
 * @author brian
 * @date 2021-09-01
 */

// This is a shader that is specific to rendering sprite particles.  It
// emulates fixed-function OpenGL point sprites.

#extension GL_GOOGLE_include_directive : enable
#include "shadersnew/common.inc.glsl"

uniform mat4 p3d_ModelViewMatrix;
uniform mat4 p3d_ModelMatrix;
uniform vec4 p3d_ColorScale;

in vec4 p3d_Vertex;
in vec4 p3d_Color;

in float rotate;
in vec2 size;

#if ANIMATED || TRAIL
in float spawn_time;
#endif

#if ANIMATED
in vec3 anim_data;
in vec3 anim_data2;
#define anim_index int(anim_data.x)
#define anim_fps (anim_data.y)
#define anim_first_frame int(anim_data.z)
#define anim_num_frames int(anim_data2.x)
#define anim_loop bool(anim_data2.y)
#define anim_interp bool(anim_data2.z)

flat out int v_anim_frame;
flat out int v_anim_next_frame;
flat out float v_anim_frac;
uniform float osg_FrameTime;
#endif

#if TRAIL
in vec3 prev_pos;
in vec3 initial_pos;
out vec3 v_pos_world;
out vec3 v_initial_pos_world;
out vec3 v_prev_pos_world;
flat out float v_spawn_time;
#endif

//====================================================
// Half-Life 2 basis
#define OO_SQRT_2 0.70710676908493042
#define OO_SQRT_3 0.57735025882720947
#define OO_SQRT_6 0.40824821591377258
// sqrt( 2 / 3 )
#define OO_SQRT_2_OVER_3 0.81649661064147949

#define NUM_BUMP_VECTS 3

const vec3 g_localBumpBasis[3] = vec3[](
    vec3(OO_SQRT_2_OVER_3, 0.0f, OO_SQRT_3),
    vec3(-OO_SQRT_6, OO_SQRT_2, OO_SQRT_3),
    vec3(-OO_SQRT_6, -OO_SQRT_2, OO_SQRT_3)
);
//====================================================

#if DIRECT_LIGHT || AMBIENT_LIGHT
out vec3 v_normal;
uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ViewMatrixInverse;
#endif

#if DIRECT_LIGHT
uniform struct p3d_LightSourceParameters {
    vec4 color;
    vec4 position;
    vec4 direction;
    vec4 spotParams;
    vec3 attenuation;
} p3d_LightSource[4];
layout(constant_id = 0) const int NUM_LIGHTS = 0;
flat out vec3 v_basis_lighting0;
flat out vec3 v_basis_lighting1;
flat out vec3 v_basis_lighting2;
flat out vec3 v_hl2_basis_world0;
flat out vec3 v_hl2_basis_world1;
flat out vec3 v_hl2_basis_world2;
#endif // DIRECT_LIGHT

out vec4 v_vertex_color;
out float v_rotate;
out vec2 v_size;

void
main() {
  gl_Position = p3d_ModelViewMatrix * p3d_Vertex;
  v_rotate = rotate;
  v_size = size;

  vec3 pos_world = (p3d_ModelMatrix * p3d_Vertex).xyz;

#if TRAIL
  v_pos_world = pos_world;
  v_initial_pos_world = (p3d_ModelMatrix * vec4(initial_pos, 1.0)).xyz;
  v_prev_pos_world = (p3d_ModelMatrix * vec4(prev_pos, 1.0)).xyz;
  v_spawn_time = spawn_time;
#endif

#if ANIMATED
  float elapsed = osg_FrameTime - spawn_time;
  float fframe = elapsed * anim_fps;
  int frame = int(fframe);
  if (anim_loop) {
    frame %= anim_num_frames;
  } else {
    frame = min(frame, anim_num_frames - 1);
  }
  int next_frame = frame + 1;
  if (anim_loop) {
    next_frame %= anim_num_frames;
  } else {
    next_frame = min(next_frame, anim_num_frames - 1);
  }

  v_anim_frame = frame + anim_first_frame;
  if (anim_interp) {
    v_anim_next_frame = next_frame + anim_first_frame;
  } else {
    v_anim_next_frame = v_anim_frame;
  }
  v_anim_frac = fframe - int(fframe);
#endif

#if DIRECT_LIGHT || AMBIENT_LIGHT
  vec3 eye_dir = normalize(p3d_ViewMatrix * vec4(pos_world, 1)).xyz;
  vec3 normal = normalize(p3d_ViewMatrixInverse * vec4(eye_dir, 0)).xyz;
  normal = -normal;
  v_normal = normal;
#endif

#if DIRECT_LIGHT
  // Calculate world space basis.
  bool is_z = false;
  if (abs(normal.x) >= abs(normal.y) && abs(normal.x) >= abs(normal.z)) {
  } else if (abs(normal.y) >= abs(normal.z)) {
  } else {
    is_z = true;
  }
  vec3 v0 = is_z ? vec3(1, 0, 0) : vec3(0, 0, 1);
  vec3 tangent = normalize(cross(v0, normal));
  vec3 bitangent = normalize(cross(tangent, normal));
  vec3 basis_world0, basis_world1, basis_world2;
  basis_world0.x = dot(g_localBumpBasis[0], tangent);
  basis_world0.y = dot(g_localBumpBasis[0], bitangent);
  basis_world0.z = dot(g_localBumpBasis[0], normal);
  basis_world1.x = dot(g_localBumpBasis[1], tangent);
  basis_world1.y = dot(g_localBumpBasis[1], bitangent);
  basis_world1.z = dot(g_localBumpBasis[1], normal);
  basis_world2.x = dot(g_localBumpBasis[2], tangent);
  basis_world2.y = dot(g_localBumpBasis[2], bitangent);
  basis_world2.z = dot(g_localBumpBasis[2], normal);
  v_hl2_basis_world0 = basis_world0;
  v_hl2_basis_world1 = basis_world1;
  v_hl2_basis_world2 = basis_world2;
  v_basis_lighting0 = vec3(0);
  v_basis_lighting1 = vec3(0);
  v_basis_lighting2 = vec3(0);
  // Accumulate direct lighting into HL2 basis.
  for (int i = 0; i < NUM_LIGHTS; ++i) {
    bool isDirectional = p3d_LightSource[i].color.w == 1.0;
    bool isSpot = p3d_LightSource[i].direction.w == 1.0;
    bool isPoint = !(isDirectional || isSpot);

    vec3 lightColor = p3d_LightSource[i].color.rgb;
    vec3 lightPos = p3d_LightSource[i].position.xyz;
    vec3 lightDir = normalize(p3d_LightSource[i].direction.xyz);
    vec3 attenParams = p3d_LightSource[i].attenuation;
    vec4 spotParams = p3d_LightSource[i].spotParams;

    float lightDist = 0.0;
    float lightAtten = 1.0;

    vec3 L;
    if (isDirectional) {
      L = lightDir;
    } else {
      L = lightPos - pos_world;
      lightDist = max(0.00001, length(L));
      L = normalize(L);

      lightAtten = 1.0 / (attenParams.x + attenParams.y * lightDist + attenParams.z * (lightDist * lightDist));

      if (isSpot) {
        // Spotlight cone attenuation.
        float cosTheta = clamp(dot(L, -lightDir), 0, 1);
        float spotAtten = (cosTheta - spotParams.z) * spotParams.w;
        spotAtten = max(0.0001, spotAtten);
        spotAtten = pow(spotAtten, spotParams.x);
        spotAtten = clamp(spotAtten, 0, 1);
        lightAtten *= spotAtten;
      }
    }

    //float fNdotL = max(0.0, dot(L, normal));

    vec3 diffuseLighting = lightColor * lightAtten;

    // Accumulate into HL2 basis.
    vec3 weights = vec3(dot(L, basis_world0), dot(L, basis_world1), dot(L, basis_world2));
    weights = clamp(weights, 0, 1);

    v_basis_lighting0 += diffuseLighting * weights.x;
    v_basis_lighting1 += diffuseLighting * weights.y;
    v_basis_lighting2 += diffuseLighting * weights.z;
  }
#endif

  vec4 color_scale = p3d_ColorScale;
  vec4 vertex_color = p3d_Color;
  GammaToLinear(color_scale);
  GammaToLinear(vertex_color);
  v_vertex_color = vertex_color * color_scale;
}
