class_name Player
extends CharacterBody2D

@export var move_speed: float = 100.0
@export var acceleration: float = 5000.0
@export var friction: float = 5000.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.1
@export var max_health: float = 100.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var weapon_manager: WeaponManager = $WeaponManager

enum State { IDLE, WALK, DASH }
var state: State = State.IDLE
var input_dir: Vector2 = Vector2.ZERO
var dash_dir: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0

var is_invulnerable := false
var current_health: float

signal health_changed(current: float, maximum: float)
signal player_died()

func _enter_tree() -> void:
	add_to_group("player")

func _ready():
	current_health = max_health

func _physics_process(delta):
	input_dir = _get_input_direction()
	
	var note_manager : NoteManager = get_tree().get_first_node_in_group("note_manager")
	if note_manager:
		if Input.is_action_just_pressed("dash"):
			var hit_type : Enums.HitType = note_manager.resolve_hit()
			print("dash:", hit_type)
			_start_dash(hit_type in [Enums.HitType.PERFECT, Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE])
		
		if Input.is_action_just_pressed("shoot"):
			# Используем WeaponManager для атаки
			if weapon_manager:
				weapon_manager.try_attack(note_manager)
		
		# Переключение оружия (опционально)
		if Input.is_action_just_pressed("switch_weapon"):
			if weapon_manager and weapon_manager.current_weapon and weapon_manager.current_weapon.weapon_data:
				# Переключаемся между типами
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

func _start_dash(invulnerable: bool):
	if state == State.DASH:
		return
	is_invulnerable = invulnerable
	dash_timer = dash_duration
	dash_dir = input_dir if input_dir != Vector2.ZERO else Vector2.RIGHT
	_change_state(State.DASH)

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

func _update_animation():
	match state:
		State.IDLE:
			pass
		State.WALK:
			pass
		State.DASH:
			pass

func _update_sprite_flip():
	if input_dir.x != 0:
		sprite.flip_h = input_dir.x < 0

# ============= DAMAGE SYSTEM =============
func take_damage(amount: float, source_position: Vector2, knockback_direction: Vector2 = Vector2.ZERO):
	if is_invulnerable:
		return
	
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	_flash_damage()
	
	# Применяем knockback только если не в dash
	if knockback_direction != Vector2.ZERO and state != State.DASH:
		# Нормализуем и применяем фиксированную силу
		velocity += knockback_direction.normalized() * 150.0
	
	if current_health <= 0:
		_die()


func _die():
	player_died.emit()
	# Логика смерти игрока


func _flash_damage():
	var original_modulate = sprite.modulate
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.15)
