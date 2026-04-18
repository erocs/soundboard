shader_type canvas_item;
#include "res://shaders/shape_functions.gdshaderinc"

uniform int shape_type : hint_range(0, 3) = 0;
uniform float border_px : hint_range(0.0, 20.0) = 8.0;
uniform float button_size_px : hint_range(1.0, 512.0) = 120.0;

void fragment() {
	float sdf = shape_sdf(UV, shape_type);

	// border_p: border width in p-space units (p spans -1..1 = button_size_px)
	float border_p = 2.0 * border_px / button_size_px;
	// 0 at edge, 1 at inner boundary of border zone
	float border_t = clamp(-sdf / border_p, 0.0, 1.0);
	float border_factor = 1.0 - border_t;

	float luma = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
	if (luma > 0.5) {
		COLOR.rgb = mix(COLOR.rgb, COLOR.rgb * 0.72, border_factor);
	} else {
		COLOR.rgb = mix(COLOR.rgb, min(COLOR.rgb + 0.22, vec3(1.0)), border_factor);
	}

	COLOR.a *= step(sdf, 0.0);
}
