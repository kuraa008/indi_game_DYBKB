shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.55;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.75;
uniform float grain_intensity : hint_range(0.0, 0.2) = 0.032;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.003;
uniform float lens_distortion : hint_range(-0.1, 0.1) = 0.012;
uniform float fear_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fear_color : source_color = vec4(0.85, 0.06, 0.04, 1.0);
uniform float vhs_amount : hint_range(0.0, 1.0) = 1.0;
uniform float vhs_stress : hint_range(0.0, 1.0) = 0.0;

// Высококачественный процедурный 35mm пленочный шум
float film_grain(vec2 uv, float t) {
	vec2 p = uv * 3.5 + vec2(t * 14.15, t * 47.83);
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

float hash1(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
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
	float vy = SCREEN_UV.y;

	// ── Кассета: дрожание строк, полоса трекинга, срыв внизу кадра, редкие сбои ──
	float line = floor(vy / SCREEN_PIXEL_SIZE.y / 2.0);
	float burst_slot = floor(t * 0.4);
	float burst = step(0.88 - vhs_stress * 0.75, hash1(burst_slot)) * step(fract(t * 0.4), 0.14 + vhs_stress * 0.5);
	float wobble = sin(vy * 7.0 + t * 1.3) * 0.0007 + sin(vy * 90.0 + t * 9.0) * 0.00025;
	float jitter = (hash1(line + floor(t * 30.0) * 13.0) - 0.5) * 0.0011;
	float band_pos = fract(t * 0.055 + hash1(floor(t * 0.055)) * 0.6);
	float band = smoothstep(0.035, 0.0, abs(vy - band_pos));
	float tear = band * (hash1(line * 1.7 + floor(t * 24.0)) - 0.5) * 0.02;
	float head_switch = smoothstep(0.965, 1.0, vy);
	float burst_shift = burst * (hash1(floor(vy * 22.0) + floor(t * 20.0) * 3.0) - 0.5) * 0.05;
	uv.x += (wobble * (1.0 + vhs_stress * 2.5) + jitter * (1.0 + vhs_stress * 3.0) + tear + head_switch * 0.03 + burst_shift) * vhs_amount;

	// Динамическая хроматическая аберрация (усиливается при страхе и адреналине)
	float dynamic_aberration = chromatic_aberration + fear_factor * 0.006;
	vec2 dir = uv - vec2(0.5);
	float dist = length(dir);

	// Оптическое расщепление RGB каналов по краям линзы и сдвиг цвета как на плёнке
	vec2 ca_offset = dir * dynamic_aberration * (dist * 1.5);
	vec2 bleed = vec2(0.0024 + burst * 0.006, 0.0) * vhs_amount;
	float lod = 0.9 * vhs_amount;
	float r = textureLod(screen_texture, uv - ca_offset + bleed, lod + 0.6).r;
	float g = textureLod(screen_texture, uv, lod * 0.6).g;
	float b = textureLod(screen_texture, uv + ca_offset - bleed, lod + 0.6).b;
	vec3 col = vec3(r, g, b);

	// Яркость остаётся чётче цвета, как у настоящей VHS-записи
	float sharp_luma = dot(textureLod(screen_texture, uv, lod * 0.35).rgb, vec3(0.299, 0.587, 0.114));
	float soft_luma = dot(col, vec3(0.299, 0.587, 0.114));
	col += vec3(sharp_luma - soft_luma) * vhs_amount;

	// Реалистичная оптическая виньетка
	float vig = 1.0 - smoothstep(0.22, 0.92, dist * vignette_intensity);
	col = mix(col * vig, col, 1.0 - vignette_opacity);

	// Натуральное зерно (более заметно в глубоких тенях, устраняет постеризацию)
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float grain_weight = mix(1.4, 0.35, clamp(luma, 0.0, 1.0));
	float grain = film_grain(SCREEN_UV * 2.5, t) * grain_intensity * grain_weight;
	col += vec3(grain);

	// ── Изображение с кассеты: блёклый цвет, приподнятый чёрный, строки, помехи ──
	if (vhs_amount > 0.001) {
		vec3 tape = mix(vec3(luma), col, 0.78);
		tape = tape * vec3(1.02, 0.98, 0.93) + vec3(0.018, 0.016, 0.022);
		float scan = 0.94 + 0.06 * sin(vy / SCREEN_PIXEL_SIZE.y * PI * 0.5);
		tape *= scan;
		float noise_val = film_grain(vec2(SCREEN_UV.x * 40.0, line * 0.37), t);
		tape += vec3(noise_val) * (0.022 + vhs_stress * 0.05 + band * 0.22 + head_switch * 0.38 + burst * 0.1);
		float speck_row = step(0.9985, hash1(line * 0.73 + floor(t * 18.0) * 7.0));
		float speck = speck_row * step(0.55, hash1(floor(SCREEN_UV.x * 26.0) + line));
		tape += vec3(speck * 0.45);
		col = mix(col, tape, vhs_amount);
	}

	// Пульсация ужаса / адреналина по краям экрана
	if (fear_factor > 0.01) {
		vec3 blood_tint = col * fear_color.rgb * 1.4;
		col = mix(col, blood_tint, clamp(fear_factor * dist * 1.3, 0.0, 0.85));
	}

	COLOR = vec4(col, 1.0);
}
