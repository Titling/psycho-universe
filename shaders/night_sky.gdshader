// Ночное небо, общее для квартиры и Мира 1. Времени в шейдере нет,
// поэтому небо считается один раз и почти ничего не стоит.
shader_type sky;

uniform vec3 horizon : source_color = vec3(0.022, 0.028, 0.04);   // как цвет тумана: дома растворяются в небе
uniform vec3 zenith : source_color = vec3(0.004, 0.007, 0.018);
uniform vec3 moon_dir = vec3(-0.08, 0.51, -0.86);
uniform float moon_size = 0.0007;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float clouds(vec3 d) {
	vec3 p = vec3(d.x, d.y * 2.5, d.z) * 3.0;
	float v = noise(p) * 0.5 + noise(p * 2.1) * 0.27 + noise(p * 4.3) * 0.15 + noise(p * 8.7) * 0.08;
	return smoothstep(0.48, 0.74, v);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, 0.0, 1.0);
	vec3 c = mix(horizon, zenith, pow(up, 0.55));

	// звёзды: одна на ячейку, разной яркости
	vec3 cell = floor(d * 170.0);
	float r = hash(cell);
	if (r > 0.985) {
		vec3 center = (cell + 0.5 + (vec3(hash(cell + 3.1), hash(cell + 7.7), hash(cell + 13.3)) - 0.5) * 0.6) / 170.0;
		float star = smoothstep(0.0035, 0.0005, distance(d, normalize(center)));
		c += vec3(0.4, 0.44, 0.55) * star * (r - 0.985) / 0.015 * smoothstep(0.02, 0.2, d.y);
	}

	// луна с ореолом
	vec3 m = normalize(moon_dir);
	float angle = 1.0 - dot(d, m);
	float disc = smoothstep(moon_size, moon_size * 0.8, angle);
	float pits = 0.8 + 0.2 * noise(d * 90.0);
	float halo = exp(-angle * 45.0) * 0.04 + exp(-angle * 400.0) * 0.08;
	c += vec3(0.5, 0.58, 0.72) * halo;

	// облака закрывают звёзды и подсвечены луной
	float cover = clouds(d) * smoothstep(-0.02, 0.2, d.y);
	vec3 cloud_color = mix(vec3(0.008, 0.01, 0.016), vec3(0.05, 0.058, 0.08), exp(-angle * 18.0));
	c = mix(c, cloud_color, cover * 0.85);
	c = mix(c, vec3(0.55, 0.57, 0.62) * pits, disc * (1.0 - cover * 0.6));

	COLOR = c;
}
