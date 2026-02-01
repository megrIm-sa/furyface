// res://shaders/blood_surface.gdshader
shader_type canvas_item;

uniform sampler2D waveform_tex;
uniform float amplitude = 12.0;
uniform vec4 blood_color : source_color = vec4(0.6, 0.0, 0.0, 1.0);
uniform float wave_offset = 0.0;  // Смещение по Y (для позиционирования)

void fragment() {
	vec2 uv = UV;
	
	// Берём значение осциллографа по X
	float sample = texture(waveform_tex, vec2(uv.x, 0.5)).r;
	sample = sample * 2.0 - 1.0; // [0..1] → [-1..1]
	
	// Вычисляем позицию волны (центр + смещение от осциллограммы)
	float wave_y = 0.5 + sample * amplitude * 0.01;
	
	// Создаем мягкую границу волны
	float dist = uv.y - wave_y;
	float alpha = smoothstep(-0.02, 0.02, -dist);
	
	// Верхняя часть - прозрачная, нижняя - цвет крови
	if (dist > 0.0) {
		COLOR = vec4(blood_color.rgb, alpha * blood_color.a);
	} else {
		COLOR = blood_color;
	}
}
