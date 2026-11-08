shader_type spatial;
render_mode cull_disabled;

// Шкура скинвокера для кат-сцены «Крейн»: та же чёрная кожа, но может сползать
// вниз, как мокрая одежда (slide 0 → 1), и блестеть (wet).

uniform vec4 base_col : source_color = vec4(0.035, 0.03, 0.033, 1.0);
uniform sampler2D normal_tex : hint_normal;
uniform float slide = 0.0;
uniform float top = 2.75;
uniform float wet = 0.0;

varying float sag;

void vertex() {
	float level = mix(top, 0.03, slide);
	float h = VERTEX.y;
	sag = 0.0;
	if (h > level) {
		float d = h - level;
		VERTEX.y = level + d * 0.1;
		VERTEX.xz *= 1.0 + d * 0.85;
		sag = d;
	}
}

void fragment() {
	ALBEDO = base_col.rgb * COLOR.rgb * (1.0 - min(sag, 1.0) * 0.3);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.9;
	float w = clamp(wet + sag * 1.5, 0.0, 1.0);
	ROUGHNESS = mix(0.85, 0.25, w);
	SPECULAR = mix(0.2, 0.7, w);
	RIM = 0.12;
	RIM_TINT = 0.5;
}
