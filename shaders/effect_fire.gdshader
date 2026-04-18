shader_type canvas_item;
render_mode blend_add;
#include "res://shaders/shape_functions.gdshaderinc"
uniform int shape_type : hint_range(0, 3) = 0;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i),             hash21(i + vec2(1, 0)), f.x),
		mix(hash21(i + vec2(0,1)), hash21(i + vec2(1, 1)), f.x),
		f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.0) * 0.25 + noise(p * 4.0) * 0.125;
}

void fragment() {
	vec2 uv = UV;
	float t  = TIME;

	// Distort UV upward to produce rising motion
	vec2 uv2 = uv + vec2(fbm(uv * 2.0 + vec2(0.0, -t * 0.8)) - 0.5, -t * 1.5) * 0.3;

	float fire = fbm(uv2 * 3.0 + vec2(0.0, -t * 1.2));
	// Stronger at bottom, fades to zero at top
	fire = clamp(fire * (1.2 - uv.y), 0.0, 1.0);

	// Transparent → dark red → orange → yellow → white tip
	vec3 col = mix(vec3(0.0),          vec3(0.9, 0.0, 0.0), smoothstep(0.00, 0.25, fire));
	col       = mix(col,               vec3(1.0, 0.5, 0.0), smoothstep(0.25, 0.50, fire));
	col       = mix(col,               vec3(1.0, 0.9, 0.1), smoothstep(0.50, 0.75, fire));
	col       = mix(col,               vec3(1.0, 1.0, 0.9), smoothstep(0.75, 1.00, fire));

	COLOR = vec4(col, smoothstep(0.05, 0.3, fire) * 0.9);
	COLOR.a *= shape_mask(UV, shape_type);
}
