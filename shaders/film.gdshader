// Постобработка поверх 3D-картинки (интерфейс она не трогает): ореолы вокруг огня,
// холодные тени и тёплые света, тёмные углы, лёгкое зерно.
// sanity — потеря рассудка, когда рядом Тень: картинка плывёт и двоится.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float bloom = 0.55;
uniform float bloom_threshold = 0.45;
uniform float bloom_radius = 0.022;
uniform float grain = 0.025;
uniform float vignette = 0.85;
uniform float contrast = 1.12;
uniform float saturation = 0.72;
uniform float brightness = 1.0;
uniform float sanity = 0.0;

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 bright(vec2 uv) {
	vec3 c = texture(screen, uv).rgb;
	return c * smoothstep(bloom_threshold, 1.0, max(c.r, max(c.g, c.b)));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - 0.5;

	// картинка плывёт волнами
	uv += vec2(sin(uv.y * 9.0 + TIME * 1.3), cos(uv.x * 7.0 + TIME * 1.1)) * 0.009 * sanity;
	float split = (0.0007 + 0.006 * sanity) * (0.4 + dot(from_center, from_center) * 2.5);

	vec3 c;
	c.r = texture(screen, uv + from_center * split * 2.0).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv - from_center * split * 2.0).b;

	// ореол: несколько выборок по двум кольцам, поворот от шума прячет ступеньки
	float angle = rnd(FRAGCOORD.xy) * 6.283;
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		float a = angle + float(i) * 0.5236;
		float r = bloom_radius * (i % 2 == 0 ? 1.0 : 2.3);
		glow += bright(uv + vec2(cos(a) * 0.5625, sin(a)) * r);
	}
	c += glow / 12.0 * bloom;

	c *= brightness;
	// опорная точка низкая: контраст не должен съедать детали в темноте
	c = max((c - 0.15) * contrast + 0.15, vec3(0.0));

	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	// тени уходят в синеву, света в янтарь
	c += mix(vec3(-0.012, 0.0, 0.028), vec3(0.03, 0.008, -0.03), smoothstep(0.05, 0.65, luma));

	float edge = smoothstep(0.28, 0.85, length(from_center * vec2(1.2, 1.0)));
	c *= 1.0 - edge * vignette;

	c += (rnd(FRAGCOORD.xy + fract(TIME) * 91.0) - 0.5) * grain;

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
