shader_type canvas_item;
render_mode blend_add;
#include "res://shaders/shape_functions.gdshaderinc"
uniform int shape_type : hint_range(0, 3) = 0;

float hash(float n)  { return fract(sin(n) * 43758.5453); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2  uv = UV;
	float t  = TIME;

	// Discrete glitch frames
	float gt = floor(t * 12.0);

	// Random horizontal band displacement
	float band     = floor(uv.y * 10.0);
	float shift    = (hash(band + gt) - 0.5) * 0.25
	               * step(0.75, hash(band * 7.3 + gt));

	// Chromatic aberration — each channel on a slightly different UV
	float r = step(0.90, hash2(floor(vec2(uv.x + shift, uv.y) * 20.0) + vec2(gt, 0.0)));
	float g = step(0.90, hash2(floor(uv                        * 20.0) + vec2(0.0, gt)));
	float b = step(0.90, hash2(floor(vec2(uv.x - shift, uv.y) * 20.0) + vec2(gt,  gt)));

	// Scan-line brightness variation
	float scan = 0.5 + 0.5 * step(0.5, fract(uv.y * 25.0 + t * 2.0));

	// Rare full-row flash in magenta/violet
	float row_flash = step(0.95, hash(band + gt * 0.5))
	                * (0.5 + 0.5 * sin(t * 30.0));

	vec3  color = vec3(r, g, b) * scan + vec3(0.4, 0.0, 0.8) * row_flash;
	float alpha = clamp((r + g + b) * 0.5 * scan + row_flash * 0.4, 0.0, 0.9);

	COLOR = vec4(color, alpha);
	COLOR.a *= shape_mask(UV, shape_type);
}
