// Screen-space ambient occlusion shader
// Adapted from the three.js example: http://threejs.org/examples/#webgl_postprocessing_ssao
// Originally ported to three.js by alteredq: http://alteredqualia.com/
// Based on SSAO GLSL shader v1.2 assembled by Martins Upitis (martinsh): http://devlog-martinsh.blogspot.co.uk/search/label/SSAO
// Original technique by Arkano22: www.gamedev.net/topic/550699-ssao-no-halo-artifacts/

#version 330

#define E 2.71828182845904523536 // Eulers number
#define GOLDEN_ANGLE 2.39996322972865332 // PI * (3.0 - sqrt(5.0)) radians. See: https://en.wikipedia.org/wiki/Golden_angle
const int samples = 16; // AO estimator samples

in vec2 l_texcoord; // UV coordinate of the pixel being processed in [0-1, 0-1]
out vec4 o_color;

uniform sampler2D depthSampler; // Depth buffer packed into texture in previous pass
uniform vec2 resolution[1]; // Render target width and height
uniform vec4 near_far_minDepth_radius; // Z-near
// Z-far
// Depth clamp, reduces haloing at screen edges
// AO radius
uniform vec4 noiseAmount_diffArea_gDisplace_gArea; // Noise amount
// Self-shadowing reduction
// Gauss bell center
// Gauss bell width

// Unpack depth value packed in RGBA value
float unpackDepth(const in vec4 rgba)
{
	const vec4 bitShift = vec4(1.0 / (256.0 * 256.0 * 256.0), 1.0 / (256.0 * 256.0), 1.0 / 256.0, 1.0);
	return dot(rgba, bitShift);
}

// Read from packed depth texture
float readDepth(const in vec2 coord)
{
	//float depth = unpackDepth(texture(depthSampler, coord));
	float depth = texture(depthSampler, coord).r;
	
	// Convert depth value to linear space
	return (2.0 * near_far_minDepth_radius.x) / ((near_far_minDepth_radius.x + near_far_minDepth_radius.y) - (depth * (near_far_minDepth_radius.y - near_far_minDepth_radius.x)));
}

float compareDepths(const in float depth1, const in float depth2, inout int far)
{
	float diff = clamp((depth1 - depth2) * 100.0, 0.0, 100.0); // Depth difference
	float area = noiseAmount_diffArea_gDisplace_gArea.w;

	// Reduce left bell width to avoid self-shadowing
	if (diff < noiseAmount_diffArea_gDisplace_gArea.z)
	{
		area = noiseAmount_diffArea_gDisplace_gArea.y;
	}
	else
	{
		far = 1;
	}

	float dd = diff - noiseAmount_diffArea_gDisplace_gArea.z;
	float gauss = pow(E, -2.0 * dd * dd / (area * area));
	return gauss;
}

float estimateAO(float depth, float dw, float dh)
{
	float dd = near_far_minDepth_radius.w - depth * near_far_minDepth_radius.w;
	vec2 vv = vec2(dw, dh);
	
	vec2 coord1 = l_texcoord + dd * vv;
	int far = 0;
	float temp1 = compareDepths(depth, readDepth(coord1), far);
	
	// Linear extrapolation to guess a second layer of depth at a discontinuity
	if (far > 0)
	{
		vec2 coord2 = l_texcoord - dd * vv;
		float temp2 = compareDepths(depth, readDepth(coord2), far);
		temp1 += (1.0 - temp1) * temp2;
	}

	return temp1;
}

// Noise generation for dithering
vec2 rand(const in vec2 coord)
{
	float noiseX = dot(coord, vec2(12.9898, 78.233));
	float noiseY = dot(coord, vec2(12.9898, 78.233) * 2.0);
	vec2 noise = clamp(fract(sin(vec2(noiseX, noiseY)) * 43758.5453), 0.0, 1.0);
	return (noise * 2.0 - 1.0) * noiseAmount_diffArea_gDisplace_gArea.x;
}

void main()
{
	float depth = readDepth(l_texcoord);
	float ao = 1.0;
	
	if(depth < 1.00) // Avoid doing SSAO on sky
	{
		float tt = clamp(depth, near_far_minDepth_radius.z, 1.0);
		
		vec2 noise = rand(l_texcoord);
		float w = (1.0 / resolution[0].x)  / tt + (noise.x * (1.0 - noise.x));
		float h = (1.0 / resolution[0].y) / tt + (noise.y * (1.0 - noise.y));
		
		// Gets the average estimated AO across sample points on a sphere using golden section spiral method
		float dz = 1.0 / float(samples);
		float z = 1.0 - dz / 2.0;
		float l = 0.0;
		for (int i = 0; i <= samples; i++)
		{
			float r = sqrt(1.0 - z);
			float pw = cos(l) * r;
			float ph = sin(l) * r;
			ao += estimateAO(depth, pw * w, ph * h);
			z = z - dz;
			l = l + GOLDEN_ANGLE;
		}
		ao /= float(samples);
	}
	
	ao = 1.0 - ao;
	o_color = vec4(vec3(ao), 1.0);
}
