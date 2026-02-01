# res://scripts/weapons/bullet.gd
class_name Bullet
extends Area2D

var velocity: Vector2
var damage: float
var lifetime: float = 0.1
var time_alive: float = 0.0
var trail_color: Color = Color(1.0, 1.0, 1.0, 0.3)
var trail_length: float = 4.0

# Trail points
var trail_points: Array[Vector2] = []
var max_trail_points: int = 3

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail_line: Line2D = $TrailLine2D

func _ready():
	# Настройка коллизий
	collision_layer = 0
	collision_mask = 2  # Враги
	
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

func initialize(start_pos: Vector2, direction: Vector2, speed: float, dmg: float, life: float = 2.0, t_color: Color = Color(0.8, 0.9, 1.0, 0.5)):
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

func _physics_process(delta):
	# Движение
	global_position += velocity * delta
	
	time_alive += delta
	
	# Обновляем trail
	_update_trail()
	
	# Удаляем по истечении времени
	if time_alive >= lifetime:
		queue_free()

func _update_trail():
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
		
		# Fade out по длине trail
		var alpha = 1.0 - (float(i) / max_trail_points)
		# Gradient не работает для каждой точки, используем width
		
	# Затухание цвета trail
	var fade = 1.0 - (time_alive / lifetime)
	trail_line.modulate = Color(1, 1, 1, fade)

func _on_body_entered(body):
	if body.has_method("take_damage"):
		# Направление отдачи
		var knockback = velocity.normalized() * 100.0
		body.take_damage(damage, global_position, knockback)
	
	# Эффект попадания
	_spawn_impact_effect()
	
	queue_free()

func _spawn_impact_effect():
	# TODO: Добавить particles или sprite для эффекта попадания
	pass
