class_name MaskVisual
extends Node2D

@export var radius: float = 8.0
@export var color: Color = Color(1.0, 0.2, 0.2, 0.3)
@export var outline_color: Color = Color(1.0, 0.4, 0.4, 0.6)
@export var outline_width: float = 3.0
@export var pulse_speed: float = 2.0
@export var pulse_min_scale: float = 0.95
@export var pulse_max_scale: float = 1.05
@export var pulse_alpha: bool = true

var time: float = 0.0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	# Вычисляем пульсацию
	var pulse = sin(time * pulse_speed) * 0.5 + 0.5  # 0.0 - 1.0
	var scale_factor = lerp(pulse_min_scale, pulse_max_scale, pulse)
	var current_radius = radius * scale_factor
	
	# Изменяем альфа для пульсации
	var alpha_pulse = pulse if pulse_alpha else 0.5
	var fill_alpha = lerp(0.15, 0.35, alpha_pulse)
	var outline_alpha = lerp(0.4, 0.8, alpha_pulse)
	
	var fill_color = Color(color.r, color.g, color.b, fill_alpha)
	var current_outline_color = Color(outline_color.r, outline_color.g, outline_color.b, outline_alpha)
	
	# Рисуем заполненный круг
	draw_circle(Vector2(0, 14), current_radius, fill_color)
	
	# Рисуем контур (несколько линий для толщины)
	for i in range(int(outline_width)):
		var offset = i * 0.5
		draw_arc(
			Vector2(0, 14),
			current_radius - offset,
			0,
			TAU,
			64,
			current_outline_color
		)
