shader_type spatial;
render_mode cull_disabled;

// Тот же рисунок героя, что в player_sprite.gdshader, плюс перекраска для кат-сцен:
// Сэм (грязь, щетина, клетчатая рубашка), Крейн (седина, рваньё, пепел),
// «что-то в отцовской одежде» (чёрная кожа). Все параметры по умолчанию = Итан.

uniform sampler2D tex_front : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D tex_back : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D tex_left : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D tex_right : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

uniform float dirt = 0.0;          // грязь пятнами
uniform float pale = 0.0;          // бледная, серая кожа
uniform float stubble = 0.0;       // щетина на челюсти
uniform float plaid = 0.0;         // клетчатая рубашка вместо куртки
uniform vec3 plaid_a : source_color = vec3(0.35, 0.08, 0.06);
uniform vec3 plaid_b : source_color = vec3(0.05, 0.05, 0.05);
uniform float trouser_dark = 0.0;  // штаны темнее и грязнее
uniform float skin_black = 0.0;    // кожа и волосы — чёрные
uniform float grey_hair = 0.0;     // седина
uniform float tatter = 0.0;        // дыры в одежде
uniform float ash = 3.0;           // рост в позе покоя: всё, что выше, уже осыпалось пеплом
uniform float wet = 0.0;           // мокрый блеск
uniform float darken = 1.0;

const float PX = 0.00172;
const vec2 SIZE_FRONT = vec2(340.0, 1056.0);
const vec2 SIZE_BACK = vec2(340.0, 1042.0);
const vec2 SIZE_LEFT = vec2(204.0, 1046.0);
const vec2 SIZE_RIGHT = vec2(202.0, 1046.0);

varying vec3 bind_pos;
varying vec3 bind_dir;
varying float shade;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.13) * 0.3 + vnoise(p * 4.37) * 0.2;
}

void vertex() {
	bind_pos = vec3(UV.x, UV.y, UV2.x);
	shade = UV2.y;
	bind_dir = COLOR.rgb * 2.0 - 1.0;
}

void fragment() {
	vec3 wn = normalize(bind_dir);
	vec3 wg = pow(abs(wn), vec3(5.0));
	wg /= max(wg.x + wg.y + wg.z, 1e-4);
	float py = 1050.0 - bind_pos.y / PX;
	float mx = bind_pos.x / PX;
	float mz = bind_pos.z / PX;
	vec3 cf = texture(tex_front, vec2(170.0 + mx, py) / SIZE_FRONT).rgb;
	vec3 cb = texture(tex_back, vec2(168.0 - mx, py) / SIZE_BACK).rgb;
	vec3 cl = texture(tex_left, vec2(88.0 + mz, py) / SIZE_LEFT).rgb;
	vec3 cr = texture(tex_right, vec2(116.5 - mz, py) / SIZE_RIGHT).rgb;
	vec3 cz = mix(cb, cf, smoothstep(-0.22, 0.22, wn.z));
	vec3 cx = wn.x > 0.0 ? cr : cl;
	float in_head = step(py, 162.0);
	cz = mix(cz, cf, in_head * smoothstep(8.0, 24.0, mz));
	float side_w = wg.x * mix(1.0, 1.0 - smoothstep(14.0, 48.0, mz), in_head);
	side_w /= max(side_w + wg.y + wg.z, 1e-4);
	vec3 base_c = mix(cz, cx, side_w);
	float lum = dot(base_c, vec3(0.3, 0.59, 0.11));
	float skin_band = smoothstep(150.0, 160.0, py) * (1.0 - smoothstep(205.0, 225.0, py)) * smoothstep(0.03, 0.09, lum) * (1.0 - smoothstep(0.97, 0.995, shade));
	base_c = mix(base_c, vec3(0.47, 0.27, 0.15) * (lum / 0.3), skin_band * 0.75);
	lum = dot(base_c, vec3(0.3, 0.59, 0.11));

	// Области рисунка: кожа по цвету, волосы — тёмное на макушке, одежда — по высоте
	float warm = base_c.r - base_c.b;
	float skin = smoothstep(0.06, 0.16, warm) * smoothstep(0.1, 0.22, lum) * step(base_c.b, base_c.g + 0.04);
	float hair = (1.0 - smoothstep(60.0, 95.0, py)) * (1.0 - smoothstep(0.16, 0.3, lum)) * in_head;
	float torso = smoothstep(150.0, 175.0, py) * (1.0 - smoothstep(560.0, 590.0, py)) * (1.0 - skin);
	float legs = smoothstep(565.0, 595.0, py) * (1.0 - smoothstep(1000.0, 1020.0, py)) * (1.0 - skin);
	vec3 c = base_c;

	if (plaid > 0.0) {
		vec2 q = vec2(bind_pos.x + bind_pos.z * 0.6, bind_pos.y) * 10.0;
		float sx = smoothstep(0.3, 0.42, abs(fract(q.x) - 0.5));
		float sy = smoothstep(0.3, 0.42, abs(fract(q.y) - 0.5));
		float fine = max(smoothstep(0.46, 0.49, abs(fract(q.x * 3.0) - 0.5)), smoothstep(0.46, 0.49, abs(fract(q.y * 3.0) - 0.5)));
		vec3 pc = mix(plaid_a, plaid_b, max(sx, sy) * 0.8);
		pc = mix(pc, plaid_b * 0.6, sx * sy * 0.7);
		pc += vec3(0.04) * fine;
		pc *= clamp(lum / 0.13, 0.45, 1.6);
		c = mix(c, pc, plaid * torso);
	}
	c = mix(c, c * vec3(0.5, 0.46, 0.42), trouser_dark * legs);

	vec3 pale_skin = vec3(lum * 1.1 + 0.05) * vec3(0.93, 0.9, 0.85);
	c = mix(c, pale_skin, pale * skin);
	float jaw = smoothstep(108.0, 122.0, py) * (1.0 - smoothstep(150.0, 162.0, py)) * skin;
	c = mix(c, c * 0.5, stubble * jaw * (0.55 + 0.45 * vnoise(bind_pos.xy * 1100.0)));
	float strands = vnoise(vec2(bind_pos.x * 260.0 + bind_pos.z * 200.0, bind_pos.y * 60.0));
	c = mix(c, vec3(0.36, 0.355, 0.34) * (0.8 + 0.3 * strands) * (0.6 + 0.4 * lum / 0.2), grey_hair * hair);
	float skin_loose = smoothstep(0.0, 0.05, warm) * smoothstep(0.035, 0.1, lum) * (1.0 - smoothstep(0.02, 0.0, base_c.g - base_c.b + 0.03));
	float black_zone = max(max(skin_loose, in_head), skin_band);
	c = mix(c, vec3(0.012, 0.011, 0.013), skin_black * black_zone);

	float dn = fbm(bind_pos.xy * 21.0 + vec2(bind_pos.z * 13.0, 0.0));
	c = mix(c, c * vec3(0.52, 0.44, 0.36), dirt * smoothstep(0.38, 0.72, dn));
	c *= (1.0 - dirt * 0.18) * darken;

	if (tatter > 0.0) {
		float hn = fbm(bind_pos.xy * 34.0 + vec2(3.1, bind_pos.z * 20.0));
		if (torso + legs > 0.5 && hn < tatter * 0.42) {
			discard;
		}
	}

	float edge = 0.0;
	if (ash < 2.9) {
		float n = fbm(vec2(bind_pos.x + bind_pos.z, bind_pos.y) * 26.0);
		float level = ash + (n - 0.5) * 0.22;
		if (bind_pos.y > level) {
			discard;
		}
		edge = 1.0 - smoothstep(0.0, 0.045, level - bind_pos.y);
		c = mix(c, vec3(0.08, 0.075, 0.07), smoothstep(0.2, 0.0, level - bind_pos.y) * 0.8);
	}

	ALBEDO = c * shade * (FRONT_FACING ? 1.0 : 0.12);
	ROUGHNESS = mix(0.9, 0.22, wet);
	SPECULAR = mix(0.35, 0.75, wet);
	EMISSION = vec3(1.0, 0.36, 0.08) * edge * 2.4;
}
