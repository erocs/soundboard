shader_type canvas_item;
#include "res://shaders/shape_functions.gdshaderinc"

uniform int shape_type : hint_range(0, 3) = 0;

void fragment() {
	// Explicitly sample the texture (required for TextureRect with a custom shader).
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= shape_mask(UV, shape_type);
}
