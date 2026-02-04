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
@export var pulse_expand_duration: float = 0.1  # Быстрое расширение
@export var pulse_contract_duration: float = 0.3  # Плавное сжатие с упругостью

var is_visible: bool = false
var current_length: float = 0.0
var current_width: float = 0.0
var attack_direction: Vector2 = Vector2.RIGHT
var current_pulse_scale: float = 1.0
var windup_progress: float = 0.0
var total_beats: int = 3
var beats_passed: int = 0

# Для плавной интерполяции между битами
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
	
	# ВОССТАНОВЛЕНО: упругая пульсация на каждом бите
	_pulse_telegraph()
	queue_redraw()

func _pulse_telegraph() -> void:
	"""Визуальная пульсация на каждый бит с упругим эффектом"""
	# Отменяем предыдущую анимацию
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()
	
	# Создаём новую анимацию с упругим эффектом
	pulse_tween = create_tween()
	pulse_tween.set_ease(Tween.EASE_OUT)
	pulse_tween.set_trans(Tween.TRANS_ELASTIC)
	
	# Быстро расширяемся до максимума
	pulse_tween.tween_property(self, "current_pulse_scale", pulse_scale_max, pulse_expand_duration)
	
	# Плавно сжимаемся до минимума с упругим эффектом
	pulse_tween.tween_property(self, "current_pulse_scale", pulse_scale_min, pulse_contract_duration)

func _process(_delta: float) -> void:
	if not is_visible:
		return
	
	# Получаем beat_progress для плавной интерполяции между битами
	var beat_sync = get_tree().get_first_node_in_group("beat_sync")
	if beat_sync and beat_sync.has_method("get_beat_progress"):
		beat_progress = beat_sync.get_beat_progress()
	
	# Постоянно перерисовываем
	queue_redraw()

func _draw() -> void:
	if not is_visible:
		return
	
	# ИСПРАВЛЕНО: вычисляем прогресс на основе битов (для цвета)
	# Плавная интерполяция с учётом текущего beat_progress
	var beats_progress_float = float(beats_passed) + beat_progress
	var progress = beats_progress_float / float(total_beats) if total_beats > 0 else 0.0
	
	# Интерполяция цвета от желтого к красному
	var color = start_color.lerp(end_color, progress)
	
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
