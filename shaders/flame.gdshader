// Язычок пламени: плоскость всегда повёрнута к камере и светится поверх всего вокруг.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float phase = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
	p.x += sin(TIME * 9.0 + phase + p.y * 6.0) * 0.05 * p.y;
	float width = 0.22 * sqrt(max(p.y, 0.0)) * (1.0 - p.y) * (1.25 + 0.15 * sin(TIME * 15.0 + phase));
	float core = 1.0 - smoothstep(0.0, max(width, 0.001), abs(p.x));
	float halo = 1.0 - smoothstep(0.0, 0.5, length(p - vec2(0.0, 0.32)));
	ALBEDO = vec3(1.0, 0.62, 0.22) * core * 1.6 + vec3(1.0, 0.45, 0.12) * halo * halo * 0.45;
	ALPHA = 1.0;
}
