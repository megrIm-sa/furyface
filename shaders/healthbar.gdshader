// res://shaders/health_bar.gdshader
shader_type canvas_item;

uniform sampler2D waveform_tex;
uniform float amplitude = 12.0;
uniform float health_percent : hint_range(0.0, 1.0) = 1.0;
uniform vec4 blood_color : source_color = vec4(0.6, 0.0, 0.0, 1.0);
uniform vec4 wave_highlight : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform float wave_line_width = 0.02;

// Параметры круглой формы
uniform bool use_circle = true;
uniform float circle_radius = 0.5;  // 0.5 = половина размера
uniform float edge_smoothness = 0.01;  // Сглаживание краев

void fragment() {
	vec2 uv = UV;

	// === КРУГЛАЯ МАСКА ===
	if (use_circle) {
		// Центр круга
		vec2 center = vec2(0.5, 0.5);
		float dist_to_center = distance(uv, center);

		// Создаем круглую маску с мягкими краями
		float circle_mask = smoothstep(circle_radius + edge_smoothness, circle_radius - edge_smoothness, dist_to_center);

		// Если за пределами круга - прозрачный
		if (circle_mask <= 0.0) {
			discard;
		}
	}

	// === КРОВЬ И ВОЛНА ===
	// Вычисляем уровень крови (от низа)
	float blood_level = health_percent;

	// Осциллограмма
	float sample = texture(waveform_tex, vec2(uv.x, 0.5)).r;
	sample = sample * 2.0 - 1.0;

	// Волна на уровне крови
	float wave_offset = sample * amplitude * 0.01;
	float wave_y = blood_level + wave_offset;

	// Перевернуто: 0 внизу, 1 вверху
	float pixel_y = 1.0 - uv.y;

	// Расстояние до волны
	float dist = pixel_y - wave_y;

	// Яркая линия волны
	float wave_line = smoothstep(wave_line_width, 0.0, abs(dist));

	// Заливка ниже волны
	float fill = step(dist, 0.0);

	// Финальный цвет
	vec3 final_color = mix(blood_color.rgb, wave_highlight.rgb, wave_line);
	float final_alpha = max(fill * blood_color.a, wave_line * wave_highlight.a);

	COLOR = vec4(final_color, final_alpha);
}
