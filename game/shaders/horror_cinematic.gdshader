shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.55;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.75;
uniform float grain_intensity : hint_range(0.0, 0.2) = 0.032;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.003;
uniform float lens_distortion : hint_range(-0.1, 0.1) = 0.012;
uniform float fear_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fear_color : source_color = vec4(0.85, 0.06, 0.04, 1.0);

// Высококачественный процедурный 35mm пленочный шум
float film_grain(vec2 uv, float t) {
	vec2 p = uv * 3.5 + vec2(t * 14.15, t * 47.83);
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

// Оптическая дисторсия объектива камеры
vec2 distort(vec2 uv, float k) {
	vec2 d = uv - vec2(0.5);
	float r2 = dot(d, d);
	return uv + d * (r2 * k);
}

void fragment() {
	float t = TIME;
	vec2 uv = distort(SCREEN_UV, lens_distortion);

	// Динамическая хроматическая аберрация (усиливается при страхе и адреналине)
	float dynamic_aberration = chromatic_aberration + fear_factor * 0.006;
	vec2 dir = uv - vec2(0.5);
	float dist = length(dir);

	// Оптическое расщепление RGB каналов по краям линзы
	vec2 ca_offset = dir * dynamic_aberration * (dist * 1.5);
	float r = texture(screen_texture, uv - ca_offset).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv + ca_offset).b;
	vec3 col = vec3(r, g, b);

	// Реалистичная оптическая виньетка
	float vig = 1.0 - smoothstep(0.22, 0.92, dist * vignette_intensity);
	col = mix(col * vig, col, 1.0 - vignette_opacity);

	// Натуральное зерно (более заметно в глубоких тенях, устраняет постеризацию)
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float grain_weight = mix(1.4, 0.35, clamp(luma, 0.0, 1.0));
	float grain = film_grain(SCREEN_UV * 2.5, t) * grain_intensity * grain_weight;
	col += vec3(grain);

	// Пульсация ужаса / адреналина по краям экрана
	if (fear_factor > 0.01) {
		vec3 blood_tint = col * fear_color.rgb * 1.4;
		col = mix(col, blood_tint, clamp(fear_factor * dist * 1.3, 0.0, 0.85));
	}

	COLOR = vec4(col, 1.0);
}
