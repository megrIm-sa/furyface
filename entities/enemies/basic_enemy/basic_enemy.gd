class_name BasicEnemy
extends Enemy

@export var debug_draw: bool = true

var attack_windup_start_beat: int = -1
var attack_direction: Vector2 = Vector2.ZERO  # Направление атаки
var telegraph_circle: Node2D = null

func _on_ready():
	pass

func _process_state(delta: float):
	if not enemy_data:
		return
	
	match state:
		State.IDLE:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK_WINDUP:
			_state_attack_windup(delta)
		State.ATTACK_STRIKE:
			_state_attack_strike(delta)

func _state_idle(delta: float):
	stop_moving(delta)
	
	if target and is_target_in_range(enemy_data.detection_range):
		change_state(State.CHASE)

func _state_chase(delta: float):
	if not target:
		change_state(State.IDLE)
		return
	
	# Затухание knockback
	if velocity.length() > enemy_data.move_speed:
		velocity = velocity.move_toward(velocity.normalized() * enemy_data.move_speed, 500.0 * delta)
	
	if not is_target_in_range(enemy_data.detection_range * 1.5):
		change_state(State.IDLE)
		return
	
	if is_target_in_range(enemy_data.attack_range):
		stop_moving(delta)
	else:
		move_towards_target(delta)

func _state_attack_windup(delta: float):
	stop_moving(delta)
	
	var beats_passed = int(floor(current_beat)) - attack_windup_start_beat
	
	if beats_passed >= enemy_data.windup_beats:
		_perform_strike()

func _state_attack_strike(delta: float):
	stop_moving(delta)
	
	await get_tree().create_timer(0.2).timeout
	if state == State.ATTACK_STRIKE:
		change_state(State.CHASE)

func _on_beat(beat: int):
	match state:
		State.CHASE:
			if is_target_in_range(enemy_data.attack_range):
				_start_attack_windup(beat)

func _start_attack_windup(beat: int):
	attack_windup_start_beat = beat
	attack_direction = get_direction_to_target()  # Фиксируем направление
	
	change_state(State.ATTACK_WINDUP)
	attack_started.emit()

func _perform_strike():
	change_state(State.ATTACK_STRIKE)
	
	# Проверяем попадание в направленной области
	_check_directional_attack_hit()
	
	if anim and anim.has_animation("attack"):
		anim.play("attack")

func _check_directional_attack_hit():
	if not target or not enemy_data:
		return
	
	# Используем PhysicsDirectSpaceState2D для направленной атаки
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Создаём сектор атаки (круг для простоты)
	var shape = CircleShape2D.new()
	shape.radius = enemy_data.attack_range
	query.shape = shape
	
	# Позиция атаки смещена в направлении игрока
	var attack_offset = attack_direction * (enemy_data.attack_range * 0.5)
	query.transform = Transform2D(0, global_position + attack_offset)
	
	query.collision_mask = 1  # Layer 1 = player
	query.exclude = [get_rid()]
	
	var results = space_state.intersect_shape(query, 32)
	
	for result in results:
		var body = result.collider
		
		if body == target and _is_in_attack_arc(body):
			# Проверяем неуязвимость
			if not target.is_invulnerable:
				var knockback_dir = (target.global_position - global_position).normalized()
				var knockback_vel = knockback_dir * enemy_data.knockback_force
				
				if target.has_method("take_damage"):
					target.take_damage(enemy_data.damage, global_position, knockback_vel)
					attack_hit.emit(target, enemy_data.damage)

func _is_in_attack_arc(body: Node2D) -> bool:
	# Проверяем, находится ли цель в дуге атаки
	var to_target = (body.global_position - global_position).normalized()
	var angle = attack_direction.angle_to(to_target)
	return abs(angle) <= deg_to_rad(enemy_data.attack_arc / 2.0)

func _draw():
	if not debug_draw or not enemy_data:
		return
	
	# Рисуем радиус обнаружения (слабый)
	draw_arc(Vector2.ZERO, enemy_data.detection_range, 0, TAU, 32, Color(0.5, 0.5, 1, 0.2), 1.0)
	
	# Рисуем радиус атаки
	draw_arc(Vector2.ZERO, enemy_data.attack_range, 0, TAU, 32, Color(1, 0.5, 0, 0.3), 1.0)
	
	# Во время замаха рисуем направленную зону атаки
	if state == State.ATTACK_WINDUP:
		var beats_passed = current_beat - attack_windup_start_beat
		var progress = beats_passed / enemy_data.windup_beats
		
		# Цвет от жёлтого к красному
		var color = Color(1, 1 - progress, 0, 0.3)
		
		# Рисуем дугу атаки в направлении игрока
		var half_arc = deg_to_rad(enemy_data.attack_arc / 2.0)
		var direction_angle = attack_direction.angle()
		
		draw_arc(
			Vector2.ZERO,
			enemy_data.attack_range,
			direction_angle - half_arc,
			direction_angle + half_arc,
			16,
			color,
			3.0
		)
		
		# Направление атаки
		var dir_end = attack_direction * enemy_data.attack_range
		draw_line(Vector2.ZERO, dir_end, Color(1, 0, 0, 0.6), 2.0)

func _process(_delta):
	if debug_draw and state == State.ATTACK_WINDUP:
		queue_redraw()
