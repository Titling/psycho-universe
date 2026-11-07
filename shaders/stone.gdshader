// Основной материал: текстура и карта нормалей накладываются по мировым координатам,
// поэтому коробке любого размера не нужна развёртка. Низ стен темнеет от сырости,
// а большие пятна грязи не дают заметить повтор текстуры.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 emission : source_color = vec3(0.0);
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 0.333; // сколько повторов текстуры на метр
uniform float normal_strength = 1.0;
uniform float roughness = 0.82;
uniform bool vertical_grain = false; // на стенках доски идут сверху вниз (шкафы, ножки)

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 wn = normalize(world_normal);
	vec3 n = abs(wn);
	vec2 uv;
	vec3 t;
	vec3 b;
	bool floor_or_ceiling = n.y > n.x && n.y > n.z;
	if (floor_or_ceiling) {
		uv = world_pos.xz;
		t = vec3(1.0, 0.0, 0.0);
		b = vec3(0.0, 0.0, 1.0);
	} else if (n.x > n.z) {
		uv = vec2(world_pos.z, -world_pos.y);
		t = vec3(0.0, 0.0, 1.0);
		b = vec3(0.0, -1.0, 0.0);
	} else {
		uv = vec2(world_pos.x, -world_pos.y);
		t = vec3(1.0, 0.0, 0.0);
		b = vec3(0.0, -1.0, 0.0);
	}
	if (vertical_grain && !floor_or_ceiling) {
		uv = uv.yx;
		vec3 swap = t;
		t = b;
		b = swap;
	}
	vec3 color = texture(tex, uv * tex_scale).rgb;
	// второй, очень крупный слой той же текстуры: пятна вместо ровного повтора
	float patches = dot(texture(tex, uv * tex_scale * 0.13 + 0.37).rgb, vec3(0.33));
	color *= mix(0.72, 1.3, smoothstep(0.05, 0.4, patches));
	if (!floor_or_ceiling) {
		color *= mix(0.5, 1.0, smoothstep(0.0, 1.5, world_pos.y));
	}
	ALBEDO = albedo.rgb * color;
	EMISSION = emission;
	ROUGHNESS = roughness;

	vec2 nm_xy = (texture(tex_normal, uv * tex_scale).rg * 2.0 - 1.0) * normal_strength;
	float nm_z = sqrt(clamp(1.0 - dot(nm_xy, nm_xy), 0.0, 1.0));
	vec3 perturbed = normalize(t * nm_xy.x + b * nm_xy.y + wn * nm_z);
	NORMAL = normalize((VIEW_MATRIX * vec4(perturbed, 0.0)).xyz);
}
