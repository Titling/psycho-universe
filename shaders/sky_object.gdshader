// Объекты «на небе» (песочные часы в Мире 2): без света и без тумана, видны издалека.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec4 color : source_color = vec4(1.0);

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
