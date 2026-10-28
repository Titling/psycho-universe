// Застывшая тень человека на стене, как после ядерного взрыва.
// pose: 0 — руки опущены, 1 — руки подняты.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float pose = 0.0;
uniform float alpha = 0.85;
uniform float lean = 0.0;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 0.5, 1.0 - UV.y);
	p.x -= lean * p.y * 0.15;
	float d = length(p - vec2(0.0, 0.89)) - 0.055;
	d = min(d, seg(p, vec2(0.0, 0.47), vec2(0.0, 0.77)) - 0.075);
	d = min(d, seg(p, vec2(0.0, 0.47), vec2(-0.07, 0.02)) - 0.035);
	d = min(d, seg(p, vec2(0.0, 0.47), vec2(0.07, 0.02)) - 0.035);
	vec2 hand = mix(vec2(0.13, 0.45), vec2(0.2, 1.0), pose);
	d = min(d, seg(p, vec2(-0.08, 0.75), vec2(-hand.x, hand.y)) - 0.03);
	d = min(d, seg(p, vec2(0.08, 0.75), hand) - 0.03);
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(0.015, -0.01, d) * alpha;
}
