shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
uniform float edge_brightness : hint_range(1.0, 3.0) = 1.8;
uniform vec4 core_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform float dither_strength : hint_range(0.0, 1.0) = 0.4;

// Анимация (передаётся из кода)
uniform float time_progress : hint_range(0.0, 1.0) = 0.0;

const float bayer_matrix[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	// Пикселизация
	vec2 pixelated_uv = floor(UV * 1.0 / pixel_size) * pixel_size;
	
	vec4 color = COLOR;
	
	// Вычисляем расстояние от центра (для градиента)
	float dist_from_center = abs(UV.y - 0.5) * 2.0;
	
	// Смешиваем цвета: яркий центр, более тёмные края
	vec4 final_color = mix(core_color, edge_color, dist_from_center);
	final_color *= edge_brightness;
	
	// Эффект "проявления" по времени
	float reveal = smoothstep(0.0, 0.3, time_progress);
	float fade = 1.0 - smoothstep(0.7, 1.0, time_progress);
	float time_alpha = reveal * fade;
	
	// Dithering для альфы
	vec2 screen_pos = FRAGCOORD.xy;
	int x = int(mod(screen_pos.x, 4.0));
	int y = int(mod(screen_pos.y, 4.0));
	float dither = bayer_matrix[y * 4 + x] / 16.0;
	
	float alpha = color.a * time_alpha;
	
	// Применяем dithering
	if (dither_strength > 0.0) {
		float dither_threshold = mix(alpha, dither, dither_strength);
		alpha = step(dither_threshold, alpha);
	}
	
	// Pixel-perfect края
	if (alpha < 0.1) {
		discard;
	}
	
	COLOR = vec4(final_color * color);
}
