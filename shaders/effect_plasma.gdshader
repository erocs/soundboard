shader_type canvas_item;
render_mode blend_add;
#include "res://shaders/shape_functions.gdshaderinc"
uniform int shape_type : hint_range(0, 3) = 0;

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Three interlocked plasma waves — offset phases so arcs move independently
	float a = sin(uv.x * 10.0 + t * 5.0 + sin(uv.y * 8.0  + t * 3.0) * 1.5);
	float b = sin(uv.y * 12.0 - t * 4.0 + sin(uv.x * 9.0  - t * 6.0) * 1.2);
	float c = sin(length(uv - vec2(0.5)) * 16.0 - t * 8.0);
	float plasma = (a + b + c) / 3.0; // -1 .. 1

	// Thin bright arc at each zero-crossing of the plasma field
	float arc  = exp(-abs(plasma) * 10.0);
	// Wider soft glow behind the arcs
	float glow = exp(-abs(plasma) * 3.0) * 0.25;

	// Per-pixel flicker so arcs look alive
	float flicker = 0.75 + 0.25 * sin(t * 20.0 + uv.x * 6.0 + uv.y * 4.0);

	// Pulsing border corona
	float ex = min(uv.x, 1.0 - uv.x);
	float ey = min(uv.y, 1.0 - uv.y);
	float border = (1.0 - smoothstep(0.0, 0.06, min(ex, ey)))
	             * (0.5 + 0.5 * sin(t * 7.0));

	// Arc colour: cyan fringe → white hot core
	vec3 color = mix(vec3(0.2, 0.6, 1.0), vec3(1.0), arc);

	float alpha = (arc * 0.9 + glow + border * 0.6) * flicker;

	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
	COLOR.a *= shape_mask(UV, shape_type);
}
