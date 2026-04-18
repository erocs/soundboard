// shape_type: 0 = square, 1 = circle, 2 = star, 3 = heart

// IQ's sdStar5 — negative inside the star, positive outside.
float sdf_star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252192);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252192);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.x * ba.y - p.y * ba.x);
}

// Returns 1.0 if uv is inside the shape, 0.0 outside.
// uv is expected in 0..1 range.
float shape_mask(vec2 uv, int shape_type) {
	vec2 p = uv * 2.0 - 1.0; // remap to -1..1
	if (shape_type == 1) {
		return step(length(p), 1.0);
	} else if (shape_type == 2) {
		p.y = -p.y; // point upward
		return step(0.0, sdf_star5(p, 0.95, 0.45));
	} else if (shape_type == 3) {
		p.y = -p.y; // tip at bottom
		p *= 1.25;
		p.y += 0.115; // center the curve (natural centroid is y≈+0.115)
		float a = dot(p, p) - 1.0;
		return step(a * a * a - p.x * p.x * p.y * p.y * p.y, 0.0);
	}
	return 1.0; // square — no clip
}

// Signed distance from shape boundary in p-space (-1..1 coords).
// Negative inside, zero at boundary, positive outside.
float shape_sdf(vec2 uv, int shape_type) {
	vec2 p = uv * 2.0 - 1.0;
	if (shape_type == 1) {
		return length(p) - 1.0;
	} else if (shape_type == 2) {
		p.y = -p.y;
		return -sdf_star5(p, 0.95, 0.45); // sdf_star5 is positive inside, so negate
	} else if (shape_type == 3) {
		p.y = -p.y;
		p *= 1.25;
		p.y += 0.115;
		float a = dot(p, p) - 1.0;
		float f = a * a * a - p.x * p.x * p.y * p.y * p.y;
		float df_dx = 2.0 * p.x * (3.0 * a * a - p.y * p.y * p.y);
		float df_dy = 6.0 * a * a * p.y - 3.0 * p.x * p.x * p.y * p.y;
		return f / max(length(vec2(df_dx, df_dy)), 0.001);
	}
	// Square box SDF
	vec2 d = abs(p) - vec2(1.0);
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}
