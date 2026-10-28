// Плёночный фильтр поверх 3D-картинки (интерфейс он не трогает):
// расслоение цветов к краям кадра, зерно, затемнённые углы,
// контраст и дизеринг с урезанной палитрой, как на старой приставке.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float aberration = 0.004;
uniform float grain = 0.07;
uniform float vignette = 0.45;
uniform float contrast = 1.1;
uniform float levels = 24.0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - 0.5;
	vec2 shift = from_center * dot(from_center, from_center) * aberration * 20.0;
	vec3 c;
	c.r = texture(screen, uv + shift).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv - shift).b;

	c = (c - 0.5) * contrast + 0.5;
	c += (rnd(floor(FRAGCOORD.xy) + fract(TIME) * 91.0) - 0.5) * grain;
	c *= 1.0 - smoothstep(0.35, 0.95, length(from_center * vec2(1.25, 1.0))) * vignette;

	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float threshold = BAYER[p.y * 4 + p.x] / 16.0 - 0.5;
	c = floor(c * levels + threshold + 0.5) / levels;

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
