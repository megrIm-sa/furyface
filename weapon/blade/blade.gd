class_name Blade
extends Weapon

@export var debug_draw: bool = true

var attack_area: Area2D
var last_attack_direction: Vector2 = Vector2.RIGHT
var attack_visual_timer: float = 0.0
var attack_visual_duration: float = 0.2

func _ready():
	_setup_hitbox()

func _setup_hitbox():
	if not weapon_data:
		return
	
	attack_area = Area2D.new()
	attack_area.name = "AttackArea"
	add_child(attack_area)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = weapon_data.range
	collision.shape = shape
	collision.name = "CollisionShape2D"
	attack_area.add_child(collision)
	
	attack_area.monitoring = false
	attack_area.collision_layer = 0
	attack_area.collision_mask = 2

func _perform_attack(hit_type: Enums.HitType, damage: float):
	if not weapon_data:
		return
	
	var blade_data = weapon_data as BladeResource
	if not blade_data:
		return
	
	# Получаем направление атаки
	var attack_direction = weapon_manager.get_player_direction()
	last_attack_direction = attack_direction
	
	# Выполняем удар
	_perform_slash(attack_direction, damage, blade_data)
	
	# Запускаем визуализацию
	attack_visual_timer = attack_visual_duration
	
	_play_slash_animation(attack_direction)

func _perform_slash(direction: Vector2, damage: float, blade_data: BladeResource):
	attack_area.force_update_transform()
	attack_area.monitoring = true
	
	await get_tree().physics_frame
	
	var all_bodies = attack_area.get_overlapping_bodies()
	
	for body in all_bodies:
		if body.has_method("take_damage") and _is_in_slash_arc(body, direction, blade_data.slash_arc):
			var knockback_velocity = direction.normalized() * blade_data.knockback_force
			body.take_damage(damage, global_position, knockback_velocity)
	
	attack_area.monitoring = false

func _is_in_slash_arc(enemy: Node2D, attack_direction: Vector2, arc: float) -> bool:
	var to_enemy = (enemy.global_position - global_position).normalized()
	var angle = attack_direction.angle_to(to_enemy)
	return abs(angle) <= deg_to_rad(arc / 2.0)

func _play_slash_animation(direction: Vector2):
	# TODO: Добавить анимацию, particles
	pass

func _process_weapon_logic(delta: float):
	if attack_visual_timer > 0.0:
		attack_visual_timer -= delta
	
	if debug_draw:
		queue_redraw()

func _on_activated():
	if debug_draw:
		queue_redraw()

func _draw():
	if not debug_draw or not is_active or not weapon_data:
		return
	
	var blade_data = weapon_data as BladeResource
	if not blade_data:
		return
	
	var range_val = blade_data.range
	
	# Радиус атаки
	draw_circle(Vector2.ZERO, range_val, Color(0, 1, 0, 0.1))
	draw_arc(Vector2.ZERO, range_val, 0, TAU, 32, Color(0, 1, 0, 0.5), 1.0)
	
	# Дуга атаки
	var half_arc = deg_to_rad(blade_data.slash_arc / 2.0)
	var direction_angle = last_attack_direction.angle()
	
	var arc_color: Color
	if attack_visual_timer > 0.0:
		arc_color = Color(1, 0, 0, 0.5)
	elif can_attack():
		arc_color = Color(0, 1, 0, 0.3)
	else:
		arc_color = Color(1, 1, 0, 0.2)
	
	draw_arc(Vector2.ZERO, range_val, direction_angle - half_arc, direction_angle + half_arc, 32, arc_color, 3.0)
	
	# Направление атаки
	var dir_end = last_attack_direction * range_val
	draw_line(Vector2.ZERO, dir_end, Color(1, 1, 1, 0.8), 2.0)
	
	# Границы дуги
	var left_boundary = Vector2(cos(direction_angle - half_arc), sin(direction_angle - half_arc)) * range_val
	var right_boundary = Vector2(cos(direction_angle + half_arc), sin(direction_angle + half_arc)) * range_val
	
	draw_line(Vector2.ZERO, left_boundary, Color(1, 0.5, 0, 0.8), 1.5)
	draw_line(Vector2.ZERO, right_boundary, Color(1, 0.5, 0, 0.8), 1.5)

func _apply_upgrade(branch_index: int, level: int):
	match branch_index:
		0:  # Ветка 1
			upgrade_branches[0].modifiers["damage_mult"] = 1.0 + level * 0.15
		1:  # Ветка 2
			upgrade_branches[1].modifiers["damage_mult"] = 1.0 + level * 0.25
			upgrade_branches[1].modifiers["cooldown_mult"] = 1.0 - level * 0.05
