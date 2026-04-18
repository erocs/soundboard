shader_type canvas_item;
render_mode blend_add;
#include "res://shaders/shape_functions.gdshaderinc"
uniform int shape_type : hint_range(0, 3) = 0;

void fragment() {
	vec2  uv   = UV;
	float t    = TIME;
	float dist = length(uv - vec2(0.5)) * 2.0; // 0 at center, ~1.4 at corners

	// Three concentric ring sets at different speeds and phases
	float r1 = sin(dist * 18.0 - t * 7.0);
	float r2 = sin(dist * 14.0 - t * 5.0 + 1.5);
	float r3 = sin(dist * 22.0 - t * 9.0 + 3.0);
	float rings = (r1 + r2 + r3) / 3.0;

	// Highlight crests; fade out toward edges
	float bright = smoothstep(0.2, 0.9, rings) * smoothstep(1.2, 0.0, dist);

	// Gentle overall pulse
	bright *= 0.65 + 0.35 * sin(t * 10.0);

	// Warm gold → white at peaks
	vec3 color = mix(vec3(1.0, 0.5, 0.1), vec3(1.0, 1.0, 0.8), bright);

	COLOR = vec4(color, clamp(bright * 0.9, 0.0, 1.0));
	COLOR.a *= shape_mask(UV, shape_type);
}
