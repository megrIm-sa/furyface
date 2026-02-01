# res://scripts/vfx/danger_zone.gd
class_name DangerZone
extends Node2D

enum Shape { CIRCLE, RECTANGLE, ARC }

@export var shape: Shape = Shape.CIRCLE
@export var radius: float = 100.0
@export var rect_size: Vector2 = Vector2(100, 100)
@export var arc_angle: float = 90.0  # В градусах
@export var arc_direction: Vector2 = Vector2.RIGHT

@export var warning_color: Color = Color(1.0, 0.5, 0.0, 0.3)  # Оранжевый
@export var danger_color: Color = Color(1.0, 0.0, 0.0, 0.5)  # Красный
@export var outline_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var outline_width: float = 2.0

@export var warning_duration: float = 1.0  # Время предупреждения
@export var active_duration: float = 0.5  # Время активной опасности

var time_elapsed: float = 0.0
var is_active: bool = false

signal zone_activated()
signal zone_finished()

func _ready():
	z_index = 0  # Под всем остальным

func _process(delta: float):
	time_elapsed += delta
	queue_redraw()
	
	# Переход в активную фазу
	if not is_active and time_elapsed >= warning_duration:
		is_active = true
		zone_activated.emit()
	
	# Завершение
	if time_elapsed >= warning_duration + active_duration:
		zone_finished.emit()
		queue_free()

func _draw():
	var current_color = danger_color if is_active else warning_color
	
	# Пульсация во время предупреждения
	if not is_active:
		var pulse = sin(time_elapsed * 8.0) * 0.5 + 0.5
		var alpha = lerp(0.2, 0.4, pulse)
		current_color.a = alpha
	
	match shape:
		Shape.CIRCLE:
			_draw_circle_zone(current_color)
		Shape.RECTANGLE:
			_draw_rectangle_zone(current_color)
		Shape.ARC:
			_draw_arc_zone(current_color)

func _draw_circle_zone(color: Color):
	# Заполнение
	draw_circle(Vector2.ZERO, radius, color)
	
	# Контур
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, outline_color, outline_width)

func _draw_rectangle_zone(color: Color):
	var rect = Rect2(-rect_size / 2, rect_size)
	
	# Заполнение
	draw_rect(rect, color)
	
	# Контур
	draw_rect(rect, outline_color, false, outline_width)

func _draw_arc_zone(color: Color):
	var start_angle = arc_direction.angle() - deg_to_rad(arc_angle / 2)
	var end_angle = arc_direction.angle() + deg_to_rad(arc_angle / 2)
	
	# Рисуем "кусок пиццы"
	var points: PackedVector2Array = [Vector2.ZERO]
	var num_segments = 32
	
	for i in range(num_segments + 1):
		var t = float(i) / num_segments
		var angle = lerp(start_angle, end_angle, t)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	
	points.append(Vector2.ZERO)
	
	# Заполнение
	draw_colored_polygon(points, color)
	
	# Контур
	draw_polyline(points, outline_color, outline_width)

func check_if_player_inside(player_pos: Vector2) -> bool:
	"""Проверяет, находится ли игрок внутри опасной зоны"""
	if not is_active:
		return false
	
	var local_pos = to_local(player_pos)
	
	match shape:
		Shape.CIRCLE:
			return local_pos.length() <= radius
		Shape.RECTANGLE:
			var rect = Rect2(-rect_size / 2, rect_size)
			return rect.has_point(local_pos)
		Shape.ARC:
			if local_pos.length() > radius:
				return false
			var angle = local_pos.angle()
			var target_angle = arc_direction.angle()
			var half_arc = deg_to_rad(arc_angle / 2)
			var angle_diff = abs(angle_difference(angle, target_angle))
			return angle_diff <= half_arc
	
	return false
