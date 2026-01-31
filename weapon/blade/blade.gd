class_name Blade
extends Weapon

@export var debug_draw: bool = true
@export var debug_logs: bool = true

var attack_area: Area2D
var last_attack_direction: Vector2 = Vector2.RIGHT
var attack_visual_timer: float = 0.0
var attack_visual_duration: float = 0.2

func _ready():
	if debug_logs:
		print("[Blade] _ready() called")
		print("[Blade]   weapon_data: %s" % weapon_data)
		if weapon_data:
			print("[Blade]   weapon_data.weapon_name: %s" % weapon_data.weapon_name)
			print("[Blade]   weapon_data.range: %.1f" % weapon_data.range)
	
	super._ready()
	
	# Ждём один кадр, чтобы убедиться что всё инициализировано
	await get_tree().process_frame
	_setup_hitbox()

func _setup_hitbox():
	if debug_logs:
		print("[Blade] _setup_hitbox() called")
	
	if not weapon_data:
		if debug_logs:
			print("[Blade] ❌ ERROR: weapon_data is null in _setup_hitbox!")
		return
	
	if debug_logs:
		print("[Blade]   Creating AttackArea...")
	
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
	
	if debug_logs:
		print("[Blade]   AttackArea created successfully")
		print("[Blade]   - radius: %.1f" % shape.radius)
		print("[Blade]   - collision_mask: %d" % attack_area.collision_mask)

func _perform_attack(hit_type: Enums.HitType, damage: float):
	if debug_logs:
		print("[Blade] ═══════════════════════════════════════")
		print("[Blade] 🗡️ _perform_attack() called")
		print("[Blade]   hit_type: %s" % Enums.HitType.keys()[hit_type])
		print("[Blade]   damage: %.1f" % damage)
	
	if not weapon_data:
		if debug_logs:
			print("[Blade] ❌ ERROR: weapon_data is null!")
		return
	
	if debug_logs:
		print("[Blade]   weapon_data OK")
	
	var blade_data = weapon_data as BladeResource
	if not blade_data:
		if debug_logs:
			print("[Blade] ❌ ERROR: weapon_data is not BladeResource! Type: %s" % weapon_data.get_class())
		return
	
	if debug_logs:
		print("[Blade]   BladeResource cast OK")
		print("[Blade]   - slash_arc: %.1f" % blade_data.slash_arc)
		print("[Blade]   - knockback_force: %.1f" % blade_data.knockback_force)
	
	# Проверяем weapon_manager
	if not weapon_manager:
		if debug_logs:
			print("[Blade] ❌ ERROR: weapon_manager is null!")
		return
	
	if debug_logs:
		print("[Blade]   weapon_manager OK")
	
	# Получаем направление атаки
	var attack_direction = weapon_manager.get_player_direction()
	last_attack_direction = attack_direction
	
	if debug_logs:
		print("[Blade]   attack_direction: (%.2f, %.2f)" % [attack_direction.x, attack_direction.y])
		print("[Blade]   global_position: %s" % global_position)
	
	# Проверяем attack_area
	if not attack_area:
		if debug_logs:
			print("[Blade] ❌ ERROR: attack_area is null! Hitbox not initialized?")
		return
	
	if debug_logs:
		print("[Blade]   attack_area OK")
	
	# Выполняем удар
	_perform_slash(attack_direction, damage, blade_data)
	
	# Запускаем визуализацию
	attack_visual_timer = attack_visual_duration
	
	_play_slash_animation(attack_direction)
	
	if debug_logs:
		print("[Blade] ═══════════════════════════════════════")

func _perform_slash(direction: Vector2, damage: float, blade_data: BladeResource):
	if debug_logs:
		print("[Blade] 🔍 _perform_slash() starting...")
		print("[Blade]   attack_area.global_position: %s" % attack_area.global_position)
		print("[Blade]   range: %.1f" % blade_data.range)
	
	attack_area.force_update_transform()
	
	if debug_logs:
		print("[Blade]   force_update_transform() done")
	
	attack_area.monitoring = true
	
	if debug_logs:
		print("[Blade]   monitoring enabled, waiting for physics frame...")
	
	await get_tree().physics_frame
	
	if debug_logs:
		print("[Blade]   physics frame passed, checking overlaps...")
	
	var all_bodies = attack_area.get_overlapping_bodies()
	
	if debug_logs:
		print("[Blade]   Found %d bodies" % all_bodies.size())
	
	# Ручная проверка для диагностики
	if all_bodies.size() == 0:
		if debug_logs:
			print("[Blade] ⚠️ No bodies found by Area2D!")
			print("[Blade] 🔧 Manual check:")
			var all_enemies = get_tree().get_nodes_in_group("enemies")
			print("[Blade]   Total enemies in scene: %d" % all_enemies.size())
			for enemy in all_enemies:
				var distance = global_position.distance_to(enemy.global_position)
				print("[Blade]     - %s: distance=%.1f, in_range=%s" % [
					enemy.name, 
					distance, 
					distance <= blade_data.range
				])
	
	var hit_count = 0
	
	for body in all_bodies:
		if debug_logs:
			print("[Blade]   Checking body: %s" % body.name)
			print("[Blade]     - has_method('take_damage'): %s" % body.has_method("take_damage"))
		
		if body.has_method("take_damage"):
			var is_in_arc = _is_in_slash_arc(body, direction, blade_data.slash_arc)
			
			if debug_logs:
				var to_enemy = (body.global_position - global_position).normalized()
				var angle = rad_to_deg(direction.angle_to(to_enemy))
				print("[Blade]     - angle: %.1f°" % angle)
				print("[Blade]     - arc limit: %.1f°" % (blade_data.slash_arc / 2.0))
				print("[Blade]     - in_arc: %s" % is_in_arc)
			
			if is_in_arc:
				var knockback_velocity = direction.normalized() * blade_data.knockback_force
				
				if debug_logs:
					print("[Blade]     ✓ Attacking! knockback: (%.1f, %.1f)" % [knockback_velocity.x, knockback_velocity.y])
				
				body.take_damage(damage, global_position, knockback_velocity)
				hit_count += 1
			else:
				if debug_logs:
					print("[Blade]     ✗ Outside arc")
	
	if debug_logs:
		if hit_count > 0:
			print("[Blade] ✨ Hit %d enemies!" % hit_count)
		else:
			print("[Blade] ❌ No enemies hit")
	
	attack_area.monitoring = false

func _is_in_slash_arc(enemy: Node2D, attack_direction: Vector2, arc: float) -> bool:
	var to_enemy = (enemy.global_position - global_position).normalized()
	var angle = attack_direction.angle_to(to_enemy)
	return abs(angle) <= deg_to_rad(arc / 2.0)

func _play_slash_animation(direction: Vector2):
	pass

func _process_weapon_logic(delta: float):
	if attack_visual_timer > 0.0:
		attack_visual_timer -= delta
	
	if debug_draw:
		queue_redraw()

func _on_activated():
	if debug_logs:
		print("[Blade] 🗡️ Activated!")
	if debug_draw:
		queue_redraw()

func _on_deactivated():
	if debug_logs:
		print("[Blade] Deactivated")

func _draw():
	if not debug_draw or not is_active or not weapon_data:
		return
	
	var blade_data = weapon_data as BladeResource
	if not blade_data:
		return
	
	var range_val = blade_data.range
	
	draw_circle(Vector2.ZERO, range_val, Color(0, 1, 0, 0.1))
	draw_arc(Vector2.ZERO, range_val, 0, TAU, 32, Color(0, 1, 0, 0.5), 1.0)
	
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
	
	var dir_end = last_attack_direction * range_val
	draw_line(Vector2.ZERO, dir_end, Color(1, 1, 1, 0.8), 2.0)
	
	var left_boundary = Vector2(cos(direction_angle - half_arc), sin(direction_angle - half_arc)) * range_val
	var right_boundary = Vector2(cos(direction_angle + half_arc), sin(direction_angle + half_arc)) * range_val
	
	draw_line(Vector2.ZERO, left_boundary, Color(1, 0.5, 0, 0.8), 1.5)
	draw_line(Vector2.ZERO, right_boundary, Color(1, 0.5, 0, 0.8), 1.5)

func _apply_upgrade(branch_index: int, level: int):
	match branch_index:
		0:
			upgrade_branches[0].modifiers["damage_mult"] = 1.0 + level * 0.15
			if debug_logs:
				print("[Blade] Upgraded branch 0 to level %d" % level)
		1:
			upgrade_branches[1].modifiers["damage_mult"] = 1.0 + level * 0.25
			upgrade_branches[1].modifiers["cooldown_mult"] = 1.0 - level * 0.05
			if debug_logs:
				print("[Blade] Upgraded branch 1 to level %d" % level)
