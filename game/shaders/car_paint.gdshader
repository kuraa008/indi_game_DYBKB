shader_type spatial;

// Старая краска машины отца: выцветание, царапины, ржавчина снизу и по пятнам,
// тёмная кайма вспученной краски вокруг ржавчины и грязь у порогов.
// Координаты берутся в пространстве модели, поэтому узор не плывёт, когда машина едет.

uniform vec3 paint : source_color = vec3(0.16, 0.22, 0.17);
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float rust_amount = 0.6;
uniform float rust_top = 0.95;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

vec4 tri(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.zy * s) * w.x + texture(t, p.xz * s) * w.y + texture(t, p.xy * s) * w.z;
}

void fragment() {
	float big = tri(noise_tex, opos, onrm, 0.55).r;
	float small = tri(noise_tex, opos, onrm, 2.4).r;
	float low = 1.0 - smoothstep(0.42, rust_top, opos.y);
	float field = big * 0.7 + small * 0.3 + low * rust_amount * 0.45;
	float rust = smoothstep(0.76, 0.8, field);
	float rim = smoothstep(0.71, 0.76, field) - rust;
	vec3 det = tri(detail_tex, opos, onrm, 0.9).rgb;
	vec3 rust_col = mix(vec3(0.12, 0.045, 0.018), vec3(0.3, 0.13, 0.045), small) * (0.65 + 0.55 * det.r);
	vec3 col = paint * (0.72 + 0.4 * det.r);
	col *= 1.0 + 0.18 * smoothstep(0.9, 1.6, opos.y) * (big - 0.4);
	col = mix(col, col * 0.5, rim);
	col = mix(col, vec3(0.11, 0.09, 0.065), low * 0.45 * small);
	ALBEDO = mix(col, rust_col, rust);
	ROUGHNESS = mix(0.42, 0.95, max(rust, low * 0.5));
	METALLIC = mix(0.32, 0.04, rust);
	SPECULAR = mix(0.5, 0.2, rust);
}
