class_name RectangleShockwaveVisualizer
extends Node2D

@export_group("Visual Settings")
@export var shockwave_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var fill_alpha: float = 0.5
@export var border_width: float = 5.0
@export var side_border_width: float = 3.0
@export var wave_thickness_percent: float = 0.15

@export_group("Animation")
@export var expansion_duration: float = 0.3
@export var fade_duration: float = 0.3

var is_active: bool = false
var shockwave_progress: float = 0.0
var current_alpha: float = 0.0
var max_length: float = 100.0
var max_width: float = 40.0
var wave_direction: Vector2 = Vector2.RIGHT

var shockwave_tween: Tween

func play_shockwave(length: float, width: float, direction: Vector2) -> void:
	"""Запускает анимацию прямоугольной ударной волны"""
	# ИСПРАВЛЕНО: если уже активна, отменяем предыдущую
	if is_active and shockwave_tween and shockwave_tween.is_running():
		shockwave_tween.kill()
	
	is_active = true
	max_length = length
	max_width = width
	wave_direction = direction.normalized()
	shockwave_progress = 0.0
	current_alpha = shockwave_color.a  # Сбрасываем альфу
	visible = true
	
	shockwave_tween = create_tween()
	shockwave_tween.set_parallel(true)
	
	# Прогресс от 0 до 1
	shockwave_tween.tween_property(self, "shockwave_progress", 1.0, expansion_duration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	
	# Затухание альфы
	shockwave_tween.tween_property(self, "current_alpha", 0.0, fade_duration)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_QUAD)
	
	shockwave_tween.finished.connect(_on_shockwave_finished, CONNECT_ONE_SHOT)

func _on_shockwave_finished() -> void:
	"""Вызывается по завершении анимации"""
	is_active = false
	visible = false
	shockwave_progress = 0.0
	current_alpha = 0.0


func _process(_delta: float) -> void:
	if is_active:
		queue_redraw()

func _draw() -> void:
	if not is_active or shockwave_progress <= 0.0:
		return
	
	# Волна движется от врага вперед
	var wave_length = max_length * shockwave_progress
	var wave_thickness = max_length * wave_thickness_percent
	var wave_start = max(0, wave_length - wave_thickness)
	
	var angle = wave_direction.angle()
	var half_width = max_width * 0.5
	
	# Углы волны вдоль оси X
	var local_corners = [
		Vector2(wave_start, -half_width),
		Vector2(wave_start, half_width),
		Vector2(wave_length, half_width),
		Vector2(wave_length, -half_width)
	]
	
	# Поворачиваем
	var world_corners: PackedVector2Array = []
	for corner in local_corners:
		world_corners.append(corner.rotated(angle))
	
	# Рисуем заполненную волну
	var fill_color = Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, current_alpha * fill_alpha)
	draw_colored_polygon(world_corners, fill_color)
	
	# Контур волны
	var border_color = Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, current_alpha)
	
	# Передний край (ярче)
	draw_line(world_corners[2], world_corners[3], border_color, border_width)
	
	# Боковые стороны
	draw_line(world_corners[0], world_corners[1], border_color, side_border_width)
	draw_line(world_corners[1], world_corners[2], border_color, side_border_width)
	draw_line(world_corners[3], world_corners[0], border_color, side_border_width)
