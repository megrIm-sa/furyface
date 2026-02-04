class_name BladeSlashVFX
extends Node2D

@export_group("Wave Configuration")
@export var wave_thickness: float = 12.0
@export var lifetime: float = 0.25
@export var wave_speed: float = 600.0

@export_group("Visual")
@export var wave_color: Color = Color(0.8, 0.9, 1.0, 0.8)
@export var trail_color: Color = Color(0.5, 0.7, 1.0, 0.4)
@export var edge_color: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var draw_edge_lines: bool = true

var time: float = 0.0
var is_active: bool = false
var current_distance: float = 0.0

var arc_angle: float = 90.0
var max_distance: float = 80.0

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if not is_active:
		return
	
	time += delta
	
	# Волна движется от 0 до max_distance
	current_distance = (time / lifetime) * max_distance * 1.5
	
	if time >= lifetime:
		_stop()
		return
	
	queue_redraw()

func play_slash(direction: Vector2, arc_deg: float, distance: float) -> void:
	"""Запускает анимацию волны slash"""
	arc_angle = arc_deg
	max_distance = distance
	time = 0.0
	current_distance = 0.0
	is_active = true
	visible = true
	
	# Поворачиваем волну в направлении удара
	rotation = direction.angle()
	
	queue_redraw()

func _stop() -> void:
	"""Останавливает анимацию"""
	is_active = false
	visible = false
	time = 0.0
	current_distance = 0.0

func _draw() -> void:
	if not is_active:
		return
	
	var progress = time / lifetime
	
	# Fade out эффект
	var alpha = 1.0 - smoothstep(0.6, 1.0, progress)
	
	# Ширина волны расширяется с расстоянием
	var wave_width = current_distance * tan(deg_to_rad(arc_angle / 2.0))
	
	# Рисуем шлейф за волной
	if current_distance > wave_thickness:
		_draw_wave_trail(
			max(0.0, current_distance - wave_thickness * 2.0),
			current_distance,
			Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha * 0.6)
		)
	
	# Рисуем основную волну (передний фронт)
	_draw_wave_front(
		current_distance,
		wave_thickness,
		Color(wave_color.r, wave_color.g, wave_color.b, wave_color.a * alpha)
	)
	
	# Рисуем боковые линии конуса
	if draw_edge_lines and progress < 0.7:
		_draw_cone_edges(
			current_distance,
			Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * alpha * 0.5)
		)

func _draw_wave_front(distance: float, thickness: float, color: Color) -> void:
	"""Рисует передний фронт волны - дугу"""
	if distance <= 0:
		return
	
	var points: PackedVector2Array = []
	var segments = 24
	var half_angle = deg_to_rad(arc_angle / 2.0)
	
	# Внутренняя дуга
	for i in range(segments + 1):
		var angle = lerp(-half_angle, half_angle, float(i) / segments)
		var dir = Vector2(cos(angle), sin(angle))
		points.append(dir * (distance - thickness / 2.0))
	
	# Внешняя дуга (в обратном порядке)
	for i in range(segments + 1):
		var angle = lerp(half_angle, -half_angle, float(i) / segments)
		var dir = Vector2(cos(angle), sin(angle))
		points.append(dir * (distance + thickness / 2.0))
	
	draw_colored_polygon(points, color)

func _draw_wave_trail(start_dist: float, end_dist: float, color: Color) -> void:
	"""Рисует шлейф за волной - конусообразную область"""
	if start_dist < 0:
		start_dist = 0
	
	var points: PackedVector2Array = []
	var half_angle = deg_to_rad(arc_angle / 2.0)
	var segments = 20
	
	# Ближняя дуга
	for i in range(segments + 1):
		var angle = lerp(-half_angle, half_angle, float(i) / segments)
		var dir = Vector2(cos(angle), sin(angle))
		points.append(dir * start_dist)
	
	# Дальняя дуга (в обратном порядке)
	for i in range(segments + 1):
		var angle = lerp(half_angle, -half_angle, float(i) / segments)
		var dir = Vector2(cos(angle), sin(angle))
		points.append(dir * end_dist)
	
	draw_colored_polygon(points, color)

func _draw_cone_edges(distance: float, color: Color) -> void:
	"""Рисует боковые линии конуса для большей четкости"""
	var half_angle = deg_to_rad(arc_angle / 2.0)
	
	var top_dir = Vector2(cos(half_angle), sin(half_angle))
	var bottom_dir = Vector2(cos(-half_angle), sin(-half_angle))
	
	# Верхняя линия
	draw_line(Vector2.ZERO, top_dir * distance, color, 2.0, true)
	
	# Нижняя линия
	draw_line(Vector2.ZERO, bottom_dir * distance, color, 2.0, true)
