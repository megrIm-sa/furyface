shader_type canvas_item;

uniform sampler2D waveform_tex;
uniform float amplitude = 12.0;
uniform vec4 color : source_color;

void fragment() {
	vec2 uv = UV;

	// Берём осциллограф по X
	float sample = texture(waveform_tex, vec2(uv.x, 0.5)).r;
	sample = sample * 2.0 - 1.0; // обратно в [-1..1]

	// Смещение поверхности
	float wave_y = 0.5 + sample * amplitude * 0.01;

	// Отсекаем всё выше волны
	if (uv.y > wave_y) {
		discard;
	}

	COLOR = color;
}
