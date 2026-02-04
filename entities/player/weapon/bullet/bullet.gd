class_name Bullet
extends Area2D

signal body_hit(body: Node2D)

@export_group("Collision")
@export_flags_2d_physics var collision_layer_value: int = 0
@export_flags_2d_physics var collision_mask_value: int = 2

@export_group("Trail Configuration")
@export var max_trail_points: int = 3

var velocity: Vector2
var damage: float
var lifetime: float = 2.0
var time_alive: float = 0.0
var trail_color: Color = Color(1.0, 1.0, 1.0, 0.3)

var trail_points: Array[Vector2] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail_line: Line2D = $TrailLine2D

func _ready() -> void:
	# Настройка коллизий из Inspector
	collision_layer = collision_layer_value
	collision_mask = collision_mask_value
	
	body_entered.connect(_on_body_entered)
	
	# Настройка trail
	if not trail_line:
		trail_line = Line2D.new()
		add_child(trail_line)
	
	trail_line.width = 1.0
	trail_line.default_color = trail_color
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	trail_line.antialiased = true
	trail_line.z_index = -1

func initialize(start_pos: Vector2, direction: Vector2, speed: float, dmg: float, life: float = 2.0, t_color: Color = Color(0.8, 0.9, 1.0, 0.5)) -> void:
	"""Инициализирует пулю с параметрами"""
	global_position = start_pos
	velocity = direction.normalized() * speed
	damage = dmg
	lifetime = life
	trail_color = t_color
	
	# Поворачиваем спрайт в направлении полета
	rotation = direction.angle()
	
	# Инициализируем trail
	trail_points.clear()
	trail_points.append(Vector2.ZERO)

func _physics_process(delta: float) -> void:
	# Движение
	global_position += velocity * delta
	
	time_alive += delta
	
	# Обновляем trail
	_update_trail()
	
	# Удаляем по истечении времени
	if time_alive >= lifetime:
		queue_free()

func _update_trail() -> void:
	"""Обновляет trail эффект"""
	# Добавляем новую точку в trail
	trail_points.push_front(Vector2.ZERO)
	
	# Ограничиваем количество точек
	if trail_points.size() > max_trail_points:
		trail_points.resize(max_trail_points)
	
	# Обновляем позиции точек (в локальных координатах)
	for i in range(1, trail_points.size()):
		var prev_global = to_global(trail_points[i - 1])
		trail_points[i] = to_local(prev_global - velocity * get_physics_process_delta_time())
	
	# Обновляем Line2D
	trail_line.clear_points()
	for i in range(trail_points.size()):
		trail_line.add_point(trail_points[i])
	
	# Затухание цвета trail
	var fade = 1.0 - (time_alive / lifetime)
	trail_line.modulate = Color(1, 1, 1, fade)

func _on_body_entered(body: Node2D) -> void:
	"""Обрабатывает столкновение с телом"""
	var health_component: HealthComponent = null
	
	if body.has_node("HealthComponent"):
		health_component = body.get_node("HealthComponent")
	elif body.get_parent() and body.get_parent().has_node("HealthComponent"):
		health_component = body.get_parent().get_node("HealthComponent")
	
	if health_component and not health_component.is_invulnerable:
		# Направление отдачи
		var knockback = velocity.normalized() * 100.0
		health_component.take_damage(damage, global_position, knockback)
		
		# Испускаем сигнал о попадании
		body_hit.emit(body)
		
		print("[Bullet] Hit target for %s damage" % damage)
	
	# Эффект попадания
	_spawn_impact_effect()
	
	queue_free()

func _spawn_impact_effect() -> void:
	"""Создает эффект попадания"""
	# TODO: Добавить particles или sprite для эффекта попадания
	pass
