shader_type canvas_item;
// Creature look: mutation palette (hue/saturation/value/tint), glow pulse, unstable glitch and
// the white hit flash used in battle. Works on atlas frames (offsets use TEXTURE_PIXEL_SIZE).

uniform float m_hue_shift = 0.0;
uniform float m_saturation = 1.0;
uniform float m_value = 1.0;
uniform vec4 m_tint : source_color = vec4(1.0);
uniform float m_tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float m_pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 m_pulse_color : source_color = vec4(0.5, 1.0, 0.9, 1.0);
uniform float m_unstable : hint_range(0.0, 1.0) = 0.0;
uniform float m_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 m_flash_color : source_color = vec4(1.0);

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float glitch = 0.0;
	if (m_unstable > 0.0) {
		float row = floor(UV.y / TEXTURE_PIXEL_SIZE.y / 3.0);
		float t = floor(TIME * 9.0);
		glitch = step(0.93, hash(vec2(row, t))) * m_unstable;
		uv.x += glitch * TEXTURE_PIXEL_SIZE.x * (hash(vec2(t, row)) > 0.5 ? 2.0 : -2.0);
	}
	vec4 c = texture(TEXTURE, uv);
	vec3 hsv = rgb2hsv(c.rgb);
	hsv.x = fract(hsv.x + m_hue_shift);
	hsv.y = clamp(hsv.y * m_saturation, 0.0, 1.0);
	hsv.z = clamp(hsv.z * m_value, 0.0, 1.0);
	vec3 rgb = hsv2rgb(hsv);
	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(rgb, m_tint.rgb * (lum * 1.6 + 0.28), m_tint_amount);
	if (m_pulse > 0.0) {
		float wave = sin(TIME * 2.4) * 0.5 + 0.5;
		rgb += m_pulse_color.rgb * wave * m_pulse * 0.45 * smoothstep(0.45, 0.9, lum);
	}
	rgb = mix(rgb, vec3(0.55, 1.0, 0.5), glitch * 0.5);
	rgb = mix(rgb, m_flash_color.rgb, m_flash);
	COLOR = vec4(rgb, c.a) * v_modulate;
}
