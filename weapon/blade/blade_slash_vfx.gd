# res://scripts/weapons/blade_slash_vfx.gd
class_name BladeSlashVFX
extends Node2D

@export var arc_angle: float = 90.0  # Угол конуса волны
@export var max_distance: float = 80.0  # Максимальная дальность волны
@export var wave_thickness: float = 12.0  # Толщина линии волны
@export var wave_color: Color = Color(0.8, 0.9, 1.0, 0.8)
@export var trail_color: Color = Color(0.5, 0.7, 1.0, 0.4)
@export var lifetime: float = 0.2  # Длительность эффекта
@export var wave_speed: float = 600.0  # Скорость распространения волны

# Шейдер
@export var use_pixelation: bool = true
@export var pixel_size: float = 3.0
@export var shader_material: ShaderMaterial

var time: float = 0.0
var is_active: bool = false
var current_distance: float = 0.0

func _ready():
	visible = false
	z_index = 10
	
	if use_pixelation:
		_setup_shader()

func _setup_shader():
	if not shader_material:
		shader_material = ShaderMaterial.new()
		var shader = load("res://shaders/pixel_slash_advanced.gdshader") as Shader
		if shader:
			shader_material.shader = shader
			shader_material.set_shader_parameter("pixel_size", pixel_size)
			shader_material.set_shader_parameter("edge_brightness", 2.0)
			shader_material.set_shader_parameter("core_color", Color(1.0, 1.0, 1.0, 1.0))
			shader_material.set_shader_parameter("edge_color", Color(0.3, 0.6, 1.0, 1.0))
			shader_material.set_shader_parameter("dither_strength", 0.5)
			shader_material.set_shader_parameter("time_progress", 0.0)
	
	material = shader_material

func _process(delta):
	if not is_active:
		return
	
	time += delta
	
	# Волна движется от 0 до max_distance
	current_distance = (time / lifetime) * max_distance * 1.5
	
	if time >= lifetime:
		_stop()
		return
	
	# Обновляем прогресс в шейдере
	if shader_material:
		var progress = time / lifetime
		shader_material.set_shader_parameter("time_progress", progress)
	
	queue_redraw()

func play_slash(direction: Vector2, arc_deg: float, distance: float):
	arc_angle = arc_deg
	max_distance = distance
	time = 0.0
	current_distance = 0.0
	is_active = true
	visible = true
	
	# Поворачиваем волну в направлении удара
	rotation = direction.angle()
	
	if shader_material:
		shader_material.set_shader_parameter("time_progress", 0.0)
	
	queue_redraw()

func _stop():
	is_active = false
	visible = false
	time = 0.0
	current_distance = 0.0

func _draw():
	if not is_active:
		return
	
	var progress = time / lifetime
	
	# Fade out эффект
	var alpha = 1.0 - smoothstep(0.6, 1.0, progress)
	
	# Ширина волны расширяется с расстоянием
	var wave_width = current_distance * tan(deg_to_rad(arc_angle / 2.0))
	
	# Рисуем основную волну (передний фронт)
	_draw_wave_front(
		current_distance,
		wave_width,
		wave_thickness,
		Color(wave_color.r, wave_color.g, wave_color.b, wave_color.a * alpha)
	)
	
	# Рисуем след/шлейф за волной
	if current_distance > wave_thickness:
		_draw_wave_trail(
			current_distance - wave_thickness * 2.0,
			current_distance,
			wave_width,
			Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha * 0.6)
		)
	
	# Рисуем боковые линии конуса (опционально)
	if progress < 0.7:
		_draw_cone_edges(current_distance, wave_width, alpha)

func _draw_wave_front(distance: float, width: float, thickness: float, color: Color):
	"""Рисует передний фронт волны - дугу"""
	if distance <= 0:
		return
	
	var points: PackedVector2Array = []
	var segments = 24
	
	# Вычисляем дугу на расстоянии
	var half_angle = deg_to_rad(arc_angle / 2.0)
	
	for i in range(segments + 1):
		var angle = lerp(-half_angle, half_angle, float(i) / segments)
		var dir = Vector2(cos(angle), sin(angle))
		
		# Внутренняя точка
		points.append(dir * (distance - thickness / 2.0))
	
	for i in range(segments + 1):
		var angle = lerp(half_angle, -half_angle, float(i) / segments)
		var dir = Vector2(cos(angle), sin(angle))
		
		# Внешняя точка
		points.append(dir * (distance + thickness / 2.0))
	
	draw_colored_polygon(points, color)

func _draw_wave_trail(start_dist: float, end_dist: float, width: float, color: Color):
	"""Рисует шлейф за волной - конусообразную область"""
	if start_dist <= 0:
		start_dist = 0
	
	var points: PackedVector2Array = []
	
	var half_angle = deg_to_rad(arc_angle / 2.0)
	var segments = 20
	
	# Ближняя дуга
	for i in range(segments + 1):
		var angle = lerp(-half_angle, half_angle, float(i) / segments)
		var dir = Vector2(cos(angle), sin(angle))
		var dist = start_dist if start_dist > 0 else 0
		points.append(dir * dist)
	
	# Дальняя дуга
	for i in range(segments + 1):
		var angle = lerp(half_angle, -half_angle, float(i) / segments)
		var dir = Vector2(cos(angle), sin(angle))
		points.append(dir * end_dist)
	
	draw_colored_polygon(points, color)

func _draw_cone_edges(distance: float, width: float, alpha: float):
	"""Рисует боковые линии конуса для большей четкости"""
	var half_angle = deg_to_rad(arc_angle / 2.0)
	
	var top_dir = Vector2(cos(half_angle), sin(half_angle))
	var bottom_dir = Vector2(cos(-half_angle), sin(-half_angle))
	
	var edge_color = Color(wave_color.r, wave_color.g, wave_color.b, wave_color.a * alpha * 0.5)
	
	# Верхняя линия
	draw_line(Vector2.ZERO, top_dir * distance, edge_color, 2.0, true)
	
	# Нижняя линия
	draw_line(Vector2.ZERO, bottom_dir * distance, edge_color, 2.0, true)
