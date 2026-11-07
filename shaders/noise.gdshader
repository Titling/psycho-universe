// Когда Тень близко, края кадра затягивает живой темнотой.
shader_type canvas_item;

uniform float amount = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float smoke(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 from_center = SCREEN_UV - 0.5;
	float d = length(from_center * vec2(1.2, 1.0));
	float n = smoke(from_center * 7.0 + vec2(TIME * 0.2, -TIME * 0.27)) * 0.6 + smoke(from_center * 15.0 - TIME * 0.35) * 0.4;
	float dark = smoothstep(0.62 - amount * 0.42, 0.72, d + (n - 0.5) * 0.3);
	COLOR = vec4(0.0, 0.0, 0.0, dark * clamp(amount * 1.6, 0.0, 0.96));
}
