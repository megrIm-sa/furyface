class_name RectangleTelegraphVisualizer
extends Node2D

@export_group("Visual Settings")
@export var start_color: Color = Color(1.0, 1.0, 0.0, 0.3)
@export var end_color: Color = Color(1.0, 0.0, 0.0, 0.6)
@export var border_alpha: float = 1.0
@export var border_width: float = 3.0

@export_group("Pulse Animation")
@export var pulse_scale_min: float = 0.95
@export var pulse_scale_max: float = 1.05
@export var pulse_ease_duration: float = 0.1
@export var pulse_return_duration: float = 0.3

var is_visible: bool = false
var current_length: float = 0.0
var current_width: float = 0.0
var attack_direction: Vector2 = Vector2.RIGHT
var current_pulse_scale: float = 1.0
var windup_progress: float = 0.0
var total_beats: int = 3

# ДОБАВЛЕНО: для плавной пульсации на основе beat_progress
var beats_passed: int = 0
var beat_progress: float = 0.0

var pulse_tween: Tween

func show_telegraph(length: float, width: float, direction: Vector2, beats: int) -> void:
	"""Показывает прямоугольный телеграф"""
	is_visible = true
	current_length = length
	current_width = width
	attack_direction = direction.normalized()
	total_beats = beats
	windup_progress = 0.0
	beats_passed = 0
	beat_progress = 0.0
	current_pulse_scale = pulse_scale_max
	visible = true
	queue_redraw()

func hide_telegraph() -> void:
	"""Скрывает телеграф"""
	is_visible = false
	visible = false
	current_pulse_scale = 1.0
	windup_progress = 0.0
	beats_passed = 0
	beat_progress = 0.0
	
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()
		pulse_tween = null

func update_windup_progress(beats: int, total: int) -> void:
	"""Обновляет прогресс замаха"""
	beats_passed = beats
	total_beats = total
	windup_progress = float(beats) / float(total) if total > 0 else 0.0
	
	# Пульсация на каждом бите
	_pulse()

func _process(_delta: float) -> void:
	if not is_visible:
		return
	
	# ДОБАВЛЕНО: получаем beat_progress для плавной пульсации между битами
	var beat_sync = get_tree().get_first_node_in_group("beat_sync")
	if beat_sync and beat_sync.has_method("get_beat_progress"):
		beat_progress = beat_sync.get_beat_progress()
	
	# Плавная интерполяция пульсации на основе beat_progress
	current_pulse_scale = lerp(pulse_scale_max, pulse_scale_min, beat_progress)
	
	queue_redraw()

func _pulse() -> void:
	"""Анимация пульсации на каждом бите"""
	# Отменяем автоматическую пульсацию через tween,
	# т.к. теперь используем плавную интерполяцию в _process
	pass

func _draw() -> void:
	if not is_visible:
		return
	
	# Интерполяция цвета от желтого к красному
	var color = start_color.lerp(end_color, windup_progress)
	
	# Применяем пульсацию
	var pulsing_width = current_width * current_pulse_scale
	var pulsing_length = current_length * current_pulse_scale
	
	# Вычисляем угол направления
	var angle = attack_direction.angle()
	var half_width = pulsing_width * 0.5
	
	# Строим прямоугольник вдоль оси X
	var local_corners = [
		Vector2(0, -half_width),              # Ближний левый
		Vector2(0, half_width),               # Ближний правый
		Vector2(pulsing_length, half_width),  # Дальний правый
		Vector2(pulsing_length, -half_width)  # Дальний левый
	]
	
	# Поворачиваем углы в направлении атаки
	var world_corners: PackedVector2Array = []
	for corner in local_corners:
		var rotated = corner.rotated(angle)
		world_corners.append(rotated)
	
	# Рисуем заполненный прямоугольник
	draw_colored_polygon(world_corners, color)
	
	# Рисуем контур
	var border_color = Color(color.r, color.g, color.b, border_alpha)
	for i in range(4):
		var start = world_corners[i]
		var end_point = world_corners[(i + 1) % 4]
		draw_line(start, end_point, border_color, border_width)
