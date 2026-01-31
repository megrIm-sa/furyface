class_name Player
extends CharacterBody2D

@export var move_speed: float = 100.0
@export var acceleration: float = 5000.0
@export var friction: float = 5000.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.1

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer

enum State { IDLE, WALK, DASH }
var state: State = State.IDLE
var input_dir: Vector2 = Vector2.ZERO
var dash_dir: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0

var is_invulnerable := false

func _physics_process(delta):
	input_dir = _get_input_direction()
	
	# Обработка нажатий dash и shoot в _physics_process для точного delta
	var note_manager : NoteManager = get_tree().get_first_node_in_group("note_manager")
	if note_manager:
		if Input.is_action_just_pressed("dash"):
			var hit_type : Enums.HitType = note_manager.resolve_hit(0)  # spawner_index 0 для dash
			print("dash:", hit_type)
			_start_dash(hit_type in [Enums.HitType.PERFECT, Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE])
		
		if Input.is_action_just_pressed("shoot"):
			var hit_type : Enums.HitType = note_manager.resolve_hit(1)  # spawner_index 1 для shoot
			print("shoot:", hit_type)
			# Здесь добавь логику shoot, если успех: if hit_type in [ PERFECT, GOOD_* ]
	
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

# ================= STATES =================
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

# ================= ACTIONS =================
func _start_dash(invulnerable: bool):
	if state == State.DASH:
		return
	is_invulnerable = invulnerable
	dash_timer = dash_duration
	dash_dir = input_dir if input_dir != Vector2.ZERO else Vector2.RIGHT
	_change_state(State.DASH)

# ================= HELPERS =================
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

# ================= VISUAL =================
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
