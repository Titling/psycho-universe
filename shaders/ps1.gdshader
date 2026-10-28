// Материал «под PS1»: вершины прилипают к сетке экрана (лёгкое дрожание),
// пиксельная текстура накладывается по мировым координатам (triplanar),
// поэтому коробке любого размера не нужна развёртка.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 emission : source_color = vec3(0.0);
uniform sampler2D tex : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform float tex_scale = 0.333; // сколько повторов текстуры на метр
uniform float snap = 120.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xy = floor(clip.xy / clip.w * snap) / snap * clip.w;
	POSITION = clip;
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y > n.x && n.y > n.z) {
		uv = world_pos.xz;
	} else if (n.x > n.z) {
		uv = vec2(world_pos.z, -world_pos.y);
	} else {
		uv = vec2(world_pos.x, -world_pos.y);
	}
	ALBEDO = albedo.rgb * texture(tex, uv * tex_scale).rgb;
	EMISSION = emission;
	ROUGHNESS = 1.0;
}
