// Помехи на экране, когда Тень близко.
shader_type canvas_item;

uniform float amount = 0.0;

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / 2.0);
	float n = rnd(cell + fract(TIME * 13.0) * 100.0);
	float line = step(0.97, rnd(vec2(floor(FRAGCOORD.y / 3.0), floor(TIME * 20.0))));
	COLOR = vec4(vec3(n), (n * 0.35 + line * 0.4) * amount);
}
