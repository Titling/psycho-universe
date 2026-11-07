// Панельный дом. Окна нарисованы на текстуре, поэтому горящие окна зажигаются прямо здесь:
// по UV понимаем, что это стекло, а по положению в мире решаем, горит ли оно.
shader_type spatial;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 tint = vec3(0.72, 0.72, 0.74);
uniform float night_glow = 0.05;   // чтобы дом ночью не сливался с небом
uniform vec3 warm_light = vec3(0.62, 0.36, 0.15);
uniform vec3 cold_light = vec3(0.2, 0.26, 0.38);
// Сдвиг двора: из квартиры и со двора должны гореть одни и те же окна.
uniform vec3 origin_offset = vec3(0.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - origin_offset;
}

// Центр окна на текстуре 1024x1024, если этот пиксель на стекле. Иначе x < 0.
vec2 glass_center(vec2 px) {
	float row = -1.0;
	if (px.y > 245.0 && px.y < 295.0) { row = 270.0; }
	else if (px.y > 345.0 && px.y < 388.0) { row = 366.0; }
	else if (px.y > 755.0 && px.y < 795.0) { row = 775.0; }
	else if (px.y > 838.0 && px.y < 895.0) { row = 866.0; }
	else if (px.y > 943.0 && px.y < 985.0) { row = 964.0; }
	float column = 105.0 + 77.75 * round((px.x - 105.0) / 77.75);
	if (row < 0.0 || px.x > 770.0 || abs(px.x - column) > 21.0) {
		return vec2(-1.0);
	}
	return vec2(column, row);
}

void fragment() {
	vec3 color = texture(tex, UV).rgb * tint;
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	vec3 light = vec3(0.0);
	vec2 center = glass_center(UV * 1024.0);
	if (center.x >= 0.0) {
		// Одно окно на текстуре повторяется на разных этажах, поэтому считаем, где центр
		// этого окна в мире: весь проём получает один и тот же случайный ответ.
		vec2 duv = center / 1024.0 - UV;
		vec2 ux = dFdx(UV);
		vec2 uy = dFdy(UV);
		float det = ux.x * uy.y - ux.y * uy.x;
		vec3 world_center = world_pos + dFdx(world_pos) * (duv.x * uy.y - duv.y * uy.x) / det
			+ dFdy(world_pos) * (ux.x * duv.y - ux.y * duv.x) / det;
		vec2 cell = floor(vec2(world_center.x + world_center.z, world_center.y) + 0.5);
		float r = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		light = r < 0.12 ? warm_light : (r < 0.15 ? cold_light : vec3(0.0));
	}
	EMISSION = color * night_glow + light;
}
