// Стрельчатые окна с кованым переплётом.
// mode: 0 — тёмное, 1 — горит свеча, 2 — неровное мерцание, 3 — лунный свет.
shader_type spatial;
render_mode unshaded;

uniform vec3 color : source_color = vec3(1.0, 0.8, 0.5);
uniform int mode = 0;

void fragment() {
	// стрельчатый верх: пересечение двух окружностей
	float top = 0.4;
	if (UV.y < top) {
		float h = (top - UV.y) / top;
		float half_width = 0.5 * (1.0 - h * h);
		if (abs(UV.x - 0.5) > half_width) {
			discard;
		}
	}
	vec3 c = color;
	if (mode == 1) {
		c *= 0.8 + 0.12 * sin(TIME * 5.3 + UV.x * 3.0) + 0.08 * sin(TIME * 13.0);
	} else if (mode == 2) {
		c *= 0.55 + 0.25 * sin(TIME * 7.0) + 0.2 * sin(TIME * 23.0 + 1.7);
	} else if (mode == 3) {
		c *= 0.75 + 0.25 * smoothstep(1.0, 0.0, UV.y);
	}
	// ромбики свинцового переплёта
	vec2 lattice = vec2(UV.x * 5.0 + UV.y * 6.0, UV.x * 5.0 - UV.y * 6.0);
	vec2 cell = abs(fract(lattice) - 0.5);
	if (min(cell.x, cell.y) < 0.05) {
		c *= 0.12;
	}
	vec2 e = min(UV, 1.0 - UV);
	if (min(e.x, e.y) < 0.04) {
		c *= 0.15;
	}
	ALBEDO = c;
}
