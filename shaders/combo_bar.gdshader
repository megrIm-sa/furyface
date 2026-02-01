// res://shaders/combo_bar.gdshader
shader_type canvas_item;

uniform sampler2D waveform_tex;
uniform sampler2D mask_tex;  // Маска формы (circle)
uniform float amplitude = 8.0;
uniform float health_percent : hint_range(0.0, 1.0) = 1.0;
uniform vec4 blood_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform vec4 wave_highlight : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float wave_line_width = 0.02;

// Параметры активации способности
uniform bool ability_active = false;
uniform vec4 ability_glow_color : source_color = vec4(1.0, 0.2, 0.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float glow_speed = 3.0;

uniform float time = 0.0;

void fragment() {
	vec2 uv = UV;

	// === МАСКА ФОРМЫ ===
	float mask = texture(mask_tex, uv).r;
	if (mask < 0.1) {
		discard;
	}

	// === КРОВЬ И ВОЛНА ===
	float blood_level = health_percent;

	float sample = texture(waveform_tex, vec2(uv.x, 0.5)).r;
	sample = sample * 2.0 - 1.0;

	float wave_offset = sample * amplitude * 0.01;
	float wave_y = blood_level + wave_offset;

	float pixel_y = 1.0 - uv.y;
	float dist = pixel_y - wave_y;

	float wave_line = smoothstep(wave_line_width, 0.0, abs(dist));
	float fill = step(dist, 0.0);

	vec3 final_color = mix(blood_color.rgb, wave_highlight.rgb, wave_line);
	float final_alpha = max(fill * blood_color.a, wave_line * wave_highlight.a);

	// === ЭФФЕКТ АКТИВАЦИИ СПОСОБНОСТИ ===
	if (ability_active) {
		// Пульсирующее свечение от центра
		vec2 center = vec2(0.5, 0.5);
		float dist_to_center = distance(uv, center);

		// Пульсация
		float pulse = sin(time * glow_speed) * 0.5 + 0.5;
		pulse = pulse * 0.3 + 0.7; // 0.7 - 1.0

		// Радиальное свечение
		float glow = smoothstep(0.5, 0.0, dist_to_center) * glow_intensity * pulse;

		// Смешиваем с цветом свечения
		final_color = mix(final_color, ability_glow_color.rgb, glow * 0.4);

		// Увеличиваем яркость по краям
		float edge_glow = smoothstep(0.45, 0.5, dist_to_center) * pulse * 0.5;
		final_color += ability_glow_color.rgb * edge_glow;
	}

	// Применяем маску к альфа-каналу
	final_alpha *= mask;

	COLOR = vec4(final_color, final_alpha);
}
