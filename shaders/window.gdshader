// Окна домов. mode: 0 — тёмное, 1 — горит свет, 2 — работает телевизор (мерцает).
shader_type spatial;
render_mode unshaded;

uniform vec3 color : source_color = vec3(1.0, 0.8, 0.5);
uniform int mode = 0;

void fragment() {
	vec3 c = color;
	if (mode == 2) {
		float f = 0.55 + 0.25 * sin(TIME * 7.0) + 0.2 * sin(TIME * 23.0 + 1.7);
		c *= f;
	}
	// рамка окна
	vec2 e = min(UV, 1.0 - UV);
	if (min(e.x, e.y) < 0.06) c *= 0.3;
	ALBEDO = c;
}
