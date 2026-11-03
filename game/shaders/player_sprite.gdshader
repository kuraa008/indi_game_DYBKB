shader_type spatial;

// Рисунки героя натянуты на 3D-модель: спереди, сзади и с боков берётся своя картинка.
// Точка на рисунке считается по положению в позе покоя, поэтому анимация не сдвигает рисунок.
// UV и UV2.x — положение в позе покоя, UV2.y — затенение, COLOR.rgb — направление выбора рисунка.

uniform sampler2D tex_front : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D tex_back : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D tex_left : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D tex_right : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

const float PX = 0.00172;
const vec2 SIZE_FRONT = vec2(340.0, 1056.0);
const vec2 SIZE_BACK = vec2(340.0, 1042.0);
const vec2 SIZE_LEFT = vec2(204.0, 1046.0);
const vec2 SIZE_RIGHT = vec2(202.0, 1046.0);

varying vec3 bind_pos;
varying vec3 bind_dir;
varying float shade;

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
	// Шея и верх торса получают тот же тон кожи, что и лицо
	float lum = dot(base_c, vec3(0.3, 0.59, 0.11));
	float skin_band = smoothstep(150.0, 160.0, py) * (1.0 - smoothstep(205.0, 225.0, py)) * smoothstep(0.03, 0.09, lum) * (1.0 - smoothstep(0.97, 0.995, shade));
	base_c = mix(base_c, vec3(0.47, 0.27, 0.15) * (lum / 0.3), skin_band * 0.75);
	ALBEDO = base_c * shade;
	ROUGHNESS = 0.9;
	SPECULAR = 0.35;
}
