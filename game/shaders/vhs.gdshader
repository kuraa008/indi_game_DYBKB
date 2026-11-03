shader_type canvas_item;

// Кассета: размытый цвет, строки развёртки, шум, срыв трекинга и полоса внизу кадра.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float burst : hint_range(0.0, 1.0) = 0.0; // короткий сбой плёнки
uniform float fear : hint_range(0.0, 1.0) = 0.0;  // монстр рядом — запись портится

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(vec2(i, 0.37)), hash(vec2(i + 1.0, 0.37)), f);
}

vec3 to_yiq(vec3 c) {
	return vec3(
		dot(c, vec3(0.299, 0.587, 0.114)),
		dot(c, vec3(0.596, -0.274, -0.322)),
		dot(c, vec3(0.211, -0.523, 0.312))
	);
}

vec3 to_rgb(vec3 c) {
	return vec3(
		c.x + 0.956 * c.y + 0.621 * c.z,
		c.x - 0.272 * c.y - 0.647 * c.z,
		c.x - 1.106 * c.y + 1.703 * c.z
	);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float frame = floor(t * 24.0);
	float damage = clamp(burst + fear * 0.55, 0.0, 1.0);

	// Лёгкое дрожание строк
	float wobble = (noise1(uv.y * 7.0 + t * 1.3) - 0.5) * 0.0011;
	wobble += (noise1(uv.y * 90.0 + t * 11.0) - 0.5) * 0.0005;

	// Широкая полоса трекинга, ползёт по кадру
	float band_y = fract(t * 0.027);
	float band = smoothstep(0.05, 0.0, abs(uv.y - band_y));
	wobble += band * (noise1(uv.y * 160.0 + t * 25.0) - 0.5) * (0.0012 + damage * 0.03);

	// Срыв строк во время сбоя
	float row = floor(uv.y * 90.0);
	float tear_row = step(1.0 - damage * 0.35, hash(vec2(row, frame)));
	wobble += tear_row * (hash(vec2(row, frame + 3.0)) - 0.5) * 0.09;

	// Полоса переключения головок внизу кадра
	float head = smoothstep(0.982, 0.994, uv.y);
	wobble += head * (0.012 + (hash(vec2(floor(uv.y * 240.0), frame)) - 0.5) * 0.03);

	uv.x += wobble;
	uv.y += (hash(vec2(frame, 1.7)) - 0.5) * (0.0004 + damage * 0.003);

	// Яркость чёткая, цвет размыт и сдвинут вправо
	float px = 0.0007;
	vec3 luma_a = to_yiq(texture(screen_texture, uv).rgb);
	float y_soft = to_yiq(texture(screen_texture, uv - vec2(px, 0.0)).rgb).x * 0.25
		+ luma_a.x * 0.5
		+ to_yiq(texture(screen_texture, uv + vec2(px, 0.0)).rgb).x * 0.25;
	vec2 chroma = vec2(0.0);
	float shift = 0.0022 + damage * 0.005;
	for (int i = 0; i < 5; i++) {
		float o = (float(i) - 2.0) * 0.0018 + shift;
		chroma += to_yiq(texture(screen_texture, uv + vec2(o, 0.0)).rgb).yz;
	}
	chroma *= 0.2;

	vec3 col = to_rgb(vec3(y_soft, chroma * 0.82));

	// Плёночная кривая и холодный зелёный оттенок
	col = max(col, vec3(0.0));
	col = pow(col, vec3(1.03));
	col = col * 0.97 + vec3(0.006, 0.009, 0.006);
	col *= vec3(0.95, 1.0, 0.92);

	// Шум сильнее в тенях
	float grain = hash(FRAGCOORD.xy * 0.73 + vec2(frame * 1.31, frame * 0.77)) - 0.5;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col += grain * mix(0.05, 0.022, clamp(luma * 2.0, 0.0, 1.0));
	col += (hash(vec2(floor(FRAGCOORD.y * 0.5), frame)) - 0.5) * 0.009;

	// Тонкая белая линия трекинга
	float line_y = fract(0.80 - t * 0.0065);
	float line_h = SCREEN_PIXEL_SIZE.y * 1.6;
	float line_mask = smoothstep(line_h, 0.0, abs(SCREEN_UV.y - line_y));
	float line_seg = smoothstep(0.32, 0.62, noise1(SCREEN_UV.x * 34.0 + t * 7.0));
	col += line_mask * line_seg * vec3(0.26, 0.27, 0.25);
	col += smoothstep(0.012, 0.0, abs(SCREEN_UV.y - line_y)) * 0.012;

	// Снег в полосах сбоя и внизу кадра
	float snow = hash(vec2(FRAGCOORD.x * 0.31, FRAGCOORD.y * 0.5 + frame));
	col = mix(col, vec3(snow), head * 0.32);
	col = mix(col, vec3(snow), tear_row * 0.18);
	col += band * 0.008;

	// Строки развёртки
	float scan = step(fract(FRAGCOORD.y / 3.0), 0.34);
	col *= 1.0 - scan * 0.11;

	// Виньетка кинескопа
	vec2 v = SCREEN_UV - vec2(0.5);
	v.x *= 1.15;
	col *= 1.0 - smoothstep(0.38, 0.82, length(v)) * 0.52;

	// Едва заметное мерцание лампы
	col *= 0.992 + noise1(t * 9.0) * 0.016;

	// Страх: выцветание в красный по краям
	col = mix(col, col * vec3(1.35, 0.45, 0.42), clamp(fear * length(v) * 1.6, 0.0, 0.7));

	COLOR = vec4(col, 1.0);
}
