# res://scripts/enemies/fear_mask_boss.gd
class_name FearMaskBoss
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal phase_changed(new_phase: int)
signal died()

@export var boss_name: String = "Fear Incarnate"
@export var max_health: float = 1000.0
@export var move_speed: float = 100.0
@export var attack_range: float = 150.0
@export var attack_damage: float = 30.0
@export var phase_2_health_threshold: float = 0.5

# Параметры крестообразной атаки
@export var cross_attack_width: float = 80.0
@export var cross_attack_length: float = 200.0

# Параметры атаки (в битах)
@export var windup_beats_phase1: float = 2.0
@export var windup_beats_phase2: float = 1.0
@export var attack_cooldown_beats: float = 2.0

# Визуализация
@export var debug_draw: bool = true
@export var telegraph_color_start: Color = Color(1.0, 1.0, 0.0, 0.3)
@export var telegraph_color_end: Color = Color(1.0, 0.0, 0.0, 0.6)

# Награда
@export var reward_mask_scene: PackedScene

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var mask_sprite_2d: Sprite2D = $MaskSprite2D

enum State { IDLE, CHASE, ATTACK_WINDUP, ATTACK_STRIKE, DEAD }
enum AttackType { CIRCLE, CROSS }

var state: State = State.IDLE
var current_attack_type: AttackType = AttackType.CIRCLE
var attack_type_for_shockwave: AttackType = AttackType.CIRCLE

var current_health: float
var current_phase: int = 1
var target: Player = null
var conductor: Conductor = null

var current_beat: float = 0.0
var last_beat: int = -1

var is_invulnerable: bool = false
var is_dead: bool = false

# Attack state
var attack_windup_start_beat: float = 0.0
var attack_cooldown_remaining: float = 0.0
var current_windup_beats: float = 2.0

# Визуализация
var current_pulse_scale: float = 1.0
var pulse_direction: int = 1
var is_shockwave_active: bool = false
var shockwave_radius: float = 0.0
var shockwave_alpha: float = 1.0

func _ready():
	current_health = max_health
	current_windup_beats = windup_beats_phase1
	
	add_to_group("boss")
	add_to_group("enemy")
	
	_find_dependencies()
	health_changed.emit(current_health, max_health)
	
	# Запускаем начальную анимацию
	if anim and anim.has_animation("idle"):
		anim.play("idle")
	
	print("[FearMaskBoss] Boss spawned: %s (HP: %.0f)" % [boss_name, max_health])

func _find_dependencies():
	conductor = get_tree().get_first_node_in_group("conductor")
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func _physics_process(delta):
	if is_dead:
		return
	
	if conductor:
		current_beat = conductor.get_current_beat()
		var current_beat_int = int(floor(current_beat))
		
		if current_beat_int != last_beat:
			_on_beat(current_beat_int)
			last_beat = current_beat_int
	
	_process_state(delta)
	_update_attack_visuals(delta)
	move_and_slide()
	_update_sprite_flip()
	_update_animation()
	queue_redraw()

func _process_state(delta: float):
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
	velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
	
	if target and get_distance_to_target() < 500.0:
		_change_state(State.CHASE)

func _state_chase(delta: float):
	if not target:
		_change_state(State.IDLE)
		return
	
	var distance = get_distance_to_target()
	
	if distance <= attack_range and attack_cooldown_remaining <= 0.0:
		_start_attack()
	elif distance > attack_range:
		var direction = get_direction_to_target()
		velocity = velocity.move_toward(direction * move_speed, 2000.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)

func _state_attack_windup(delta: float):
	velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
	
	var beats_passed = current_beat - attack_windup_start_beat
	
	if beats_passed >= current_windup_beats:
		_execute_attack()

func _state_attack_strike(delta: float):
	pass

func _on_beat(beat: int):
	if attack_cooldown_remaining > 0:
		attack_cooldown_remaining -= 1.0

func _start_attack():
	"""Начинает атаку"""
	_change_state(State.ATTACK_WINDUP)
	attack_windup_start_beat = current_beat
	current_pulse_scale = 0.8
	pulse_direction = 1
	
	attack_type_for_shockwave = current_attack_type
	
	print("[FearMaskBoss] Starting %s attack (windup: %.1f beats)" % [
		"CROSS" if current_attack_type == AttackType.CROSS else "CIRCLE",
		current_windup_beats
	])

func _execute_attack():
	"""Выполняет удар"""
	_change_state(State.ATTACK_STRIKE)
	
	is_shockwave_active = true
	shockwave_radius = 0.0
	shockwave_alpha = 1.0
	
	if current_attack_type == AttackType.CIRCLE:
		_check_circle_attack_hit()
	else:
		_check_cross_attack_hit()
	
	current_attack_type = AttackType.CROSS if current_attack_type == AttackType.CIRCLE else AttackType.CIRCLE
	
	await get_tree().create_timer(0.3).timeout
	attack_cooldown_remaining = attack_cooldown_beats
	_change_state(State.CHASE)

func _check_circle_attack_hit():
	"""Проверяет попадание круговой атаки"""
	if target and get_distance_to_target() <= attack_range:
		var knockback_dir = get_direction_to_target()
		target.take_damage(attack_damage, global_position, knockback_dir * 400.0)
		print("[FearMaskBoss] Circle attack hit player for %.1f damage!" % attack_damage)

func _check_cross_attack_hit():
	"""Проверяет попадание крестообразной атаки"""
	if not target:
		return
	
	var to_target = target.global_position - global_position
	
	var rects = [
		Rect2(-cross_attack_width / 2, -cross_attack_length, cross_attack_width, cross_attack_length),
		Rect2(-cross_attack_width / 2, 0, cross_attack_width, cross_attack_length),
		Rect2(-cross_attack_length, -cross_attack_width / 2, cross_attack_length, cross_attack_width),
		Rect2(0, -cross_attack_width / 2, cross_attack_length, cross_attack_width)
	]
	
	for rect in rects:
		if rect.has_point(to_target):
			var knockback_dir = to_target.normalized()
			target.take_damage(attack_damage, global_position, knockback_dir * 400.0)
			print("[FearMaskBoss] Cross attack hit player for %.1f damage!" % attack_damage)
			return

func _update_attack_visuals(delta: float):
	"""Обновляет визуальные эффекты атаки"""
	if state == State.ATTACK_WINDUP:
		var pulse_speed = 3.0
		current_pulse_scale += pulse_direction * pulse_speed * delta
		
		if current_pulse_scale >= 1.2:
			current_pulse_scale = 1.2
			pulse_direction = -1
		elif current_pulse_scale <= 0.8:
			current_pulse_scale = 0.8
			pulse_direction = 1
	
	if is_shockwave_active:
		shockwave_radius += 800.0 * delta
		shockwave_alpha -= 3.0 * delta
		
		if attack_type_for_shockwave == AttackType.CIRCLE:
			if shockwave_radius >= attack_range:
				shockwave_radius = attack_range
				shockwave_alpha -= 2.0 * delta
		else:
			if shockwave_radius >= cross_attack_length:
				shockwave_radius = cross_attack_length
				shockwave_alpha -= 2.0 * delta
		
		if shockwave_alpha <= 0.0:
			is_shockwave_active = false
			shockwave_radius = 0.0

func _update_animation():
	"""Обновляет анимацию в зависимости от состояния"""
	if not anim:
		return
	
	match state:
		State.IDLE:
			if anim.current_animation != "idle":
				anim.play("idle")
		
		State.CHASE:
			# Проверяем, движется ли босс
			if velocity.length() > 10.0:
				if anim.current_animation != "walk":
					anim.play("walk")
			else:
				if anim.current_animation != "idle":
					anim.play("idle")
		
		State.ATTACK_WINDUP:
			# Можно добавить отдельную анимацию windup
			if anim.has_animation("windup"):
				if anim.current_animation != "windup":
					anim.play("windup")
			else:
				# Или используем idle во время подготовки
				if anim.current_animation != "idle":
					anim.play("idle")
		
		State.ATTACK_STRIKE:
			# Анимация атаки проигрывается в _execute_attack()
			pass
		
		State.DEAD:
			# Анимация смерти проигрывается в _die()
			pass

func _draw():
	if not debug_draw or state == State.DEAD:
		return
	
	if state == State.ATTACK_WINDUP:
		var beats_passed = (current_beat - attack_windup_start_beat)
		var progress = beats_passed / current_windup_beats
		
		var color = telegraph_color_start.lerp(telegraph_color_end, progress)
		
		if current_attack_type == AttackType.CIRCLE:
			_draw_circle_telegraph(color)
		else:
			_draw_cross_telegraph(color)
	
	if is_shockwave_active and shockwave_radius > 0.0:
		if attack_type_for_shockwave == AttackType.CIRCLE:
			_draw_circle_shockwave()
		else:
			_draw_cross_shockwave()

func _draw_circle_telegraph(color: Color):
	"""Рисует круговую зону замаха"""
	var pulsing_radius = attack_range * current_pulse_scale
	
	draw_circle(Vector2.ZERO, pulsing_radius, color)
	draw_arc(Vector2.ZERO, pulsing_radius, 0, TAU, 32, Color(color.r, color.g, color.b, 1.0), 3.0)

func _draw_cross_telegraph(color: Color):
	"""Рисует крестообразные зоны замаха"""
	var pulse_factor = current_pulse_scale
	
	var rects = [
		Rect2(-cross_attack_width / 2 * pulse_factor, -cross_attack_length * pulse_factor, 
			cross_attack_width * pulse_factor, cross_attack_length * pulse_factor),
		Rect2(-cross_attack_width / 2 * pulse_factor, 0, 
			cross_attack_width * pulse_factor, cross_attack_length * pulse_factor),
		Rect2(-cross_attack_length * pulse_factor, -cross_attack_width / 2 * pulse_factor, 
			cross_attack_length * pulse_factor, cross_attack_width * pulse_factor),
		Rect2(0, -cross_attack_width / 2 * pulse_factor, 
			cross_attack_length * pulse_factor, cross_attack_width * pulse_factor)
	]
	
	for rect in rects:
		draw_rect(rect, color)
		draw_rect(rect, Color(color.r, color.g, color.b, 1.0), false, 3.0)

func _draw_circle_shockwave():
	"""Рисует круговую ударную волну"""
	var clamped_radius = min(shockwave_radius, attack_range)
	
	var fill_color = Color(0.8, 0.4, 1.0, shockwave_alpha * 0.3)
	draw_circle(Vector2.ZERO, clamped_radius, fill_color)
	
	var border_color = Color(1.0, 0.6, 1.0, shockwave_alpha)
	draw_arc(Vector2.ZERO, clamped_radius, 0, TAU, 32, border_color, 4.0)
	
	if clamped_radius > 5.0:
		var inner_radius = clamped_radius - 5.0
		draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 32, Color(0.8, 0.4, 1.0, shockwave_alpha * 0.5), 2.0)

func _draw_cross_shockwave():
	"""Рисует крестообразную ударную волну"""
	var expansion = min(shockwave_radius, cross_attack_length)
	
	var fill_color = Color(0.8, 0.4, 1.0, shockwave_alpha * 0.3)
	var border_color = Color(1.0, 0.6, 1.0, shockwave_alpha)
	
	var rects = [
		Rect2(-cross_attack_width / 2, -expansion, cross_attack_width, expansion),
		Rect2(-cross_attack_width / 2, 0, cross_attack_width, expansion),
		Rect2(-expansion, -cross_attack_width / 2, expansion, cross_attack_width),
		Rect2(0, -cross_attack_width / 2, expansion, cross_attack_width)
	]
	
	for rect in rects:
		draw_rect(rect, fill_color)
		draw_rect(rect, border_color, false, 4.0)
		
		var inner_rect = rect.grow(-5.0)
		if inner_rect.size.x > 0 and inner_rect.size.y > 0:
			draw_rect(inner_rect, Color(0.8, 0.4, 1.0, shockwave_alpha * 0.5), false, 2.0)

# ============= HEALTH SYSTEM =============

func take_damage(amount: float, source_position: Vector2, knockback_direction: Vector2 = Vector2.ZERO):
	if is_invulnerable or is_dead:
		return
	
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	_flash_sprite()
	
	var health_percent = current_health / max_health
	if current_phase == 1 and health_percent <= phase_2_health_threshold:
		_enter_phase_2()
	
	if current_health <= 0:
		_die()

func _enter_phase_2():
	"""Переход во вторую фазу"""
	current_phase = 2
	phase_changed.emit(2)
	
	current_windup_beats = windup_beats_phase2
	move_speed = 150.0
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.8, 0.5, 1.0, 1.0), 0.5)
	
	print("[FearMaskBoss] Entering Phase 2! (Faster attacks)")
	
	is_invulnerable = true
	await get_tree().create_timer(1.5).timeout
	is_invulnerable = false

func _die():
	if is_dead:
		return
	
	is_dead = true
	is_invulnerable = true
	_change_state(State.DEAD)
	GlobalSettings.mask = Enums.MaskType.FEAR
	died.emit()
	
	set_collision_layer_value(1, false)
	
	print("[FearMaskBoss] Boss defeated!")
	
	_grant_fear_mask_reward()
	
	if anim and anim.has_animation("death"):
		anim.play("death")
		await anim.animation_finished
	
	await get_tree().create_timer(1.0).timeout
	queue_free()
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()

func _grant_fear_mask_reward():
	"""Выдает маску страха игроку"""
	if not target or not target.mask_ability:
		return
	
	if reward_mask_scene:
		var mask = reward_mask_scene.instantiate() as BaseMask
		if mask:
			target.mask_ability.equip_mask(mask)
			print("[FearMaskBoss] Granted Fear Mask to player!")
	else:
		push_warning("[FearMaskBoss] No reward mask scene assigned!")

# ============= UTILITIES =============

func get_distance_to_target() -> float:
	if not target:
		return INF
	return global_position.distance_to(target.global_position)

func get_direction_to_target() -> Vector2:
	if not target:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()

func _update_sprite_flip():
	if not target or not sprite:
		return
	
	var to_target = target.global_position - global_position
	sprite.flip_h = to_target.x < 0
	if mask_sprite_2d:
		mask_sprite_2d.flip_h = to_target.x < 0

func _flash_sprite():
	if not sprite:
		return
	
	var original_modulate = sprite.modulate
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.15)

func _change_state(new_state: State):
	if state == new_state:
		return
	state = new_state
