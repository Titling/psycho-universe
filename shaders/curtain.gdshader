// Занавеска: складки выдавливаются прямо из плоскости, к низу они глубже.
// Ткань чуть просвечивает: свет на ней виден и с обратной стороны.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 cloth : source_color = vec3(0.2, 0.09, 0.07);
uniform float folds = 11.0;
uniform float depth = 0.045;
uniform float seed = 0.0;

float wave(float x) {
	return sin(x * folds * 6.2832 + seed) + 0.45 * sin(x * folds * 14.3 + seed * 2.1);
}

varying float fold;

void vertex() {
	float x = UV.x;
	float amount = depth * mix(0.45, 1.0, UV.y);
	float h = wave(x);
	VERTEX.z += h * amount;
	float slope = (wave(x + 0.004) - wave(x - 0.004)) / 0.008 * amount;
	NORMAL = normalize(vec3(-slope / 0.55, 0.0, 1.0));
	fold = h * 0.3 + 0.5;
}

void fragment() {
	ALBEDO = cloth * mix(0.4, 1.05, clamp(fold, 0.0, 1.0));
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	BACKLIGHT = cloth * 0.7;
}
