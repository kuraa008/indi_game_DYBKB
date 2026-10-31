shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D windows_tex : filter_linear, repeat_enable;
uniform float uv_scale : hint_range(0.01, 0.5) = 0.045;
uniform float window_brightness : hint_range(0.5, 3.0) = 1.6;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 norm = normalize(v_world_normal);
	// Абсолютно черный силуэт фасада зданий
	vec3 base_black = vec3(0.005, 0.006, 0.009);

	// Крыша и низ здания — 100% черный цвет без окон
	if (abs(norm.y) > 0.6) {
		ALBEDO = base_black;
	} else {
		// Мировые координаты фасада для идеально четкой сетки окон
		vec2 wall_uv;
		if (abs(norm.x) > abs(norm.z)) {
			wall_uv = vec2(v_world_pos.z, v_world_pos.y) * uv_scale;
		} else {
			wall_uv = vec2(v_world_pos.x, v_world_pos.y) * uv_scale;
		}

		float win_mask = texture(windows_tex, wall_uv).r;
		// Четкий порог для предотвращения размытия в серый цвет на расстоянии
		float is_lit = smoothstep(0.45, 0.65, win_mask);

		vec3 win_color = vec3(1.0, 1.0, 1.0) * window_brightness;
		ALBEDO = mix(base_black, win_color, is_lit);
	}
}
