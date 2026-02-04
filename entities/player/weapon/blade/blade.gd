class_name Blade
extends Weapon

@export_group("Dependencies")
@export var attack_area: Area2D
@export var visuals: BladeVisuals
@export var slash_vfx: BladeSlashVFX

var last_attack_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	super._ready()
	_configure_attack_area()

func _configure_attack_area() -> void:
	"""Настраивает радиус зоны атаки из weapon_data"""
	if not attack_area or not weapon_data:
		return
	
	var collision_shape = attack_area.get_node_or_null("CollisionShape2D")
	if not collision_shape:
		push_warning("Blade: CollisionShape2D not found in attack_area!")
		return
	
	var shape = collision_shape.shape as CircleShape2D
	if shape:
		shape.radius = weapon_data.range
	
	# Убеждаемся что Area2D не активна по умолчанию
	attack_area.monitoring = false

func _perform_attack(hit_type: Enums.HitType, damage: float) -> void:
	if not weapon_data:
		return
	
	var blade_data = weapon_data as BladeResource
	if not blade_data:
		return
	
	var attack_direction = get_aim_direction()
	last_attack_direction = attack_direction
	
	# Запускаем визуальную анимацию меча
	if visuals:
		visuals.play_attack_animation()
	
	# Запускаем VFX слеша
	if slash_vfx:
		slash_vfx.play_slash(attack_direction, blade_data.slash_arc, blade_data.range)
	
	# Выполняем удар
	_perform_slash(attack_direction, damage, hit_type, blade_data)

func _perform_slash(direction: Vector2, damage: float, hit_type: Enums.HitType, blade_data: BladeResource) -> void:
	"""Выполняет slash атаку и проверяет попадания"""
	if not attack_area:
		return
	
	attack_area.force_update_transform()
	attack_area.monitoring = true
	
	await get_tree().physics_frame
	
	var all_bodies = attack_area.get_overlapping_bodies()
	
	for body in all_bodies:
		var health_component: HealthComponent = null
		
		if body.has_node("HealthComponent"):
			health_component = body.get_node("HealthComponent")
		elif body.get_parent() and body.get_parent().has_node("HealthComponent"):
			health_component = body.get_parent().get_node("HealthComponent")
		
		# Проверяем, в дуге ли атаки и не неуязвим ли
		if health_component and not health_component.is_invulnerable and _is_in_slash_arc(body, direction, blade_data.slash_arc):
			var knockback_velocity = direction.normalized() * blade_data.knockback_force
			health_component.take_damage(damage, global_position, knockback_velocity)
			
			# Уведомляем о попадании через сигнал
			_notify_enemy_hit(body, damage, hit_type)
			
			print("[Blade] Hit enemy for %s damage" % damage)
	
	attack_area.monitoring = false

func _is_in_slash_arc(enemy: Node2D, attack_direction: Vector2, arc: float) -> bool:
	"""Проверяет находится ли враг в дуге атаки"""
	var to_enemy = (enemy.global_position - global_position).normalized()
	var angle = attack_direction.angle_to(to_enemy)
	return abs(angle) <= deg_to_rad(arc / 2.0)

func _on_activated() -> void:
	if visuals:
		visuals.visible = true

func _on_deactivated() -> void:
	if visuals:
		visuals.visible = false
