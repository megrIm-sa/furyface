# res://scripts/player/player.gd
class_name Player
extends CharacterBody2D

@export var move_speed: float = 100.0
@export var acceleration: float = 5000.0
@export var friction: float = 5000.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.1
@export var max_health: float = 100.0

@export_group("Dash Cooldowns (in beats)")
@export var dash_cooldown_perfect: float = 0.0
@export var dash_cooldown_good: float = 1.0
@export var dash_cooldown_miss: float = 2.0

@export_group("Animation")
@export var walk_backwards_threshold: float = -0.3  # Порог для определения движения назад

@onready var sprite: Sprite2D = $Sprite2D
@onready var mask_sprite: Sprite2D = $MaskSprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var weapon_manager: WeaponManager = $WeaponManager

enum State { IDLE, WALK, DASH, DEAD }
var state: State = State.IDLE
var input_dir: Vector2 = Vector2.ZERO
var dash_dir: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0

var is_invulnerable := false
var current_health: float
var is_dead: bool = false

# Направление взгляда (к курсору)
var facing_direction: Vector2 = Vector2.RIGHT

# Dash cooldown система
var dash_cooldown_timer: float = 0.0
var conductor: Conductor = null

signal health_changed(current: float, maximum: float)
signal player_died()
signal dash_cooldown_changed(current: float, maximum: float)

func _enter_tree() -> void:
	add_to_group("player")

func _ready():
	current_health = max_health
	
	conductor = get_tree().get_first_node_in_group("conductor")
	if not conductor:
		push_warning("Player: Conductor not found! Dash cooldown may not work correctly.")
	
	# Запускаем начальную анимацию
	if anim and anim.has_animation("idle"):
		anim.play("idle")

func _physics_process(delta):
	if is_dead:
		return
	
	input_dir = _get_input_direction()
	
	# Обновляем направление взгляда к курсору
	_update_facing_direction()
	
	# Обновляем кулдаун dash
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0.0:
			dash_cooldown_timer = 0.0
	
	var note_manager : NoteManager = get_tree().get_first_node_in_group("note_manager")
	if note_manager:
		if Input.is_action_just_pressed("dash"):
			var hit_type : Enums.HitType = note_manager.resolve_hit()
			_try_dash(hit_type)
		
		if Input.is_action_just_pressed("shoot"):
			if weapon_manager:
				weapon_manager.try_attack(note_manager)
		
		if Input.is_action_just_pressed("switch_weapon"):
			if weapon_manager and weapon_manager.current_weapon and weapon_manager.current_weapon.weapon_data:
				var current_type = weapon_manager.current_weapon.weapon_data.weapon_type
				var new_type = (
					Enums.WeaponType.REVOLVERS 
					if current_type == Enums.WeaponType.BLADE 
					else Enums.WeaponType.BLADE
				)
				weapon_manager.switch_weapon(new_type)
	
	match state:
		State.IDLE:
			_state_idle(delta)
		State.WALK:
			_state_walk(delta)
		State.DASH:
			_state_dash(delta)
		State.DEAD:
			pass
	
	move_and_slide()
	_update_sprite_flip()
	_update_animation()

func _state_idle(delta):
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	if input_dir != Vector2.ZERO:
		_change_state(State.WALK)

func _state_walk(delta):
	velocity = velocity.move_toward(
		input_dir * move_speed,
		acceleration * delta
	)
	if input_dir == Vector2.ZERO:
		_change_state(State.IDLE)

func _state_dash(delta):
	dash_timer -= delta
	velocity = dash_dir * dash_speed
	if dash_timer <= 0.0:
		is_invulnerable = false
		_change_state(State.WALK if input_dir != Vector2.ZERO else State.IDLE)

# ============= FACING & FLIP =============
func _update_facing_direction():
	"""Обновляет направление взгляда к курсору"""
	var mouse_pos = get_global_mouse_position()
	facing_direction = (mouse_pos - global_position).normalized()

func _update_sprite_flip():
	"""Разворачивает спрайт в зависимости от направления к курсору"""
	if facing_direction.x != 0:
		sprite.flip_h = facing_direction.x < 0
		if mask_sprite:
			mask_sprite.flip_h = facing_direction.x < 0

# ============= ANIMATION SYSTEM =============
func _update_animation():
	if not anim:
		return
	
	match state:
		State.IDLE:
			if anim.current_animation != "idle":
				anim.play("idle")
			anim.speed_scale = 1.0
		
		State.WALK:
			if anim.current_animation != "walk":
				anim.play("walk")
			
			# Проверяем, идет ли персонаж задом
			if _is_walking_backwards():
				anim.speed_scale = -1.0  # Инвертируем анимацию
			else:
				anim.speed_scale = 1.0
		
		State.DASH:
			# Можно добавить отдельную dash анимацию
			if anim.has_animation("dash"):
				if anim.current_animation != "dash":
					anim.play("dash")
			else:
				# Или используем walk на высокой скорости
				if anim.current_animation != "walk":
					anim.play("walk")
				anim.speed_scale = 2.0
		
		State.DEAD:
			# Анимация смерти проигрывается один раз в _die()
			pass

func _is_walking_backwards() -> bool:
	"""Проверяет, идет ли персонаж задом (движение против направления взгляда)"""
	if velocity.length() < 10.0:  # Слишком медленно
		return false
	
	# Вычисляем dot product между направлением движения и направлением взгляда
	var movement_dir = velocity.normalized()
	var dot = movement_dir.dot(facing_direction)
	
	# Если dot < 0, движение в обратную сторону
	return dot < walk_backwards_threshold

# ============= DASH SYSTEM =============
func _try_dash(hit_type: Enums.HitType):
	if not can_dash():
		print("Dash on cooldown! (%.2fs remaining)" % dash_cooldown_timer)
		return
	
	var is_successful = false
	var cooldown_beats = 0.0
	
	match hit_type:
		Enums.HitType.PERFECT:
			is_successful = true
			cooldown_beats = dash_cooldown_perfect
			print("Dash: PERFECT! No cooldown")
		
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			is_successful = true
			cooldown_beats = dash_cooldown_good
			print("Dash: GOOD! Cooldown: %.1f beats" % cooldown_beats)
		
		_:
			is_successful = false
			cooldown_beats = dash_cooldown_miss
			print("Dash: MISSED! Cooldown: %.1f beats" % cooldown_beats)
	
	_start_dash(is_successful, hit_type)
	_set_dash_cooldown(cooldown_beats)

func _start_dash(invulnerable: bool, hit_type: Enums.HitType):
	if state == State.DASH:
		return
	
	is_invulnerable = invulnerable
	dash_timer = dash_duration
	dash_dir = input_dir if input_dir != Vector2.ZERO else facing_direction
	_change_state(State.DASH)

func _set_dash_cooldown(beats: float):
	if beats <= 0.0:
		dash_cooldown_timer = 0.0
		return
	
	if conductor:
		var beat_duration = conductor.get_beat_duration()
		dash_cooldown_timer = beats * beat_duration
		dash_cooldown_changed.emit(dash_cooldown_timer, beats * beat_duration)
	else:
		var beat_duration = 60.0 / 120.0
		dash_cooldown_timer = beats * beat_duration
		push_warning("Player: Using fallback beat duration for dash cooldown")

func can_dash() -> bool:
	return dash_cooldown_timer <= 0.0 and state != State.DASH and not is_dead

func get_dash_cooldown_progress() -> float:
	if dash_cooldown_timer <= 0.0:
		return 0.0
	
	if conductor:
		var max_cooldown = dash_cooldown_miss * conductor.get_beat_duration()
		return clamp(dash_cooldown_timer / max_cooldown, 0.0, 1.0)
	return 0.0

func get_dash_cooldown_remaining_beats() -> float:
	if dash_cooldown_timer <= 0.0 or not conductor:
		return 0.0
	
	var beat_duration = conductor.get_beat_duration()
	return dash_cooldown_timer / beat_duration

# ============= STATE MANAGEMENT =============
func _change_state(new_state: State):
	if state == new_state:
		return
	state = new_state

func _get_input_direction() -> Vector2:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return dir.normalized()

# ============= DAMAGE SYSTEM =============
func take_damage(amount: float, source_position: Vector2, knockback_direction: Vector2 = Vector2.ZERO):
	if is_invulnerable or is_dead:
		return
	
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	_flash_damage()
	
	if knockback_direction != Vector2.ZERO and state != State.DASH:
		velocity += knockback_direction.normalized() * 150.0
	
	if current_health <= 0:
		_die()

func _die():
	if is_dead:
		return
	
	is_dead = true
	_change_state(State.DEAD)
	
	# Проигрываем анимацию смерти
	if anim and anim.has_animation("death"):
		anim.play("death")
		await anim.animation_finished
	
	player_died.emit()
	
	# Дополнительная логика смерти (экран game over, респавн и т.д.)

func _flash_damage():
	var original_modulate = sprite.modulate
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.15)
