// Полоса лунного света в пыльном воздухе.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(0.3, 0.42, 0.62);
uniform float strength = 0.22;

void fragment() {
	float across = 1.0 - smoothstep(0.1, 0.5, abs(UV.x - 0.5));
	float along = smoothstep(0.0, 0.1, UV.y) * (1.0 - smoothstep(0.25, 1.0, UV.y));
	float drift = 0.8 + 0.2 * sin(TIME * 0.4 + UV.y * 5.0);
	ALBEDO = color * across * along * drift * strength;
	ALPHA = 1.0;
}
