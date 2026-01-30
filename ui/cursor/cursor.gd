extends Sprite2D

@export var follow_speed: float = 25.0
@export var prediction_time: float = 0.03

@export var gamepad_speed: float = 600.0
@export var stick_deadzone: float = 0.2

var _last_mouse_pos: Vector2
var _velocity: Vector2 = Vector2.ZERO
var _virtual_cursor_pos: Vector2

enum InputMode { MOUSE, GAMEPAD }
var _input_mode := InputMode.MOUSE

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	_last_mouse_pos = get_global_mouse_position()
	_virtual_cursor_pos = _last_mouse_pos
	global_position = _last_mouse_pos

func _process(delta):
	_handle_input_mode()
	
	match _input_mode:
		InputMode.MOUSE:
			_update_from_mouse(delta)
		InputMode.GAMEPAD:
			_update_from_gamepad(delta)
	
	# Экстраполяция
	var predicted_pos := _virtual_cursor_pos + _velocity * prediction_time
	
	global_position = global_position.lerp(
		predicted_pos,
		1.0 - exp(-follow_speed * delta)
	)

func _handle_input_mode():
	if Input.get_last_mouse_velocity().length() > 0.1:
		_input_mode = InputMode.MOUSE
	elif _get_stick_input().length() > stick_deadzone:
		_input_mode = InputMode.GAMEPAD

# ---------------- MOUSE ----------------
func _update_from_mouse(delta):
	var mouse_pos := get_global_mouse_position()
	
	if delta > 0.0:
		_velocity = (mouse_pos - _last_mouse_pos) / delta
	
	_virtual_cursor_pos = mouse_pos
	_last_mouse_pos = mouse_pos

# ---------------- GAMEPAD ----------------
func _update_from_gamepad(delta):
	var stick := _get_stick_input()
	
	if stick.length() < stick_deadzone:
		_velocity = Vector2.ZERO
		return
	
	stick = stick.normalized()
	_velocity = stick * gamepad_speed
	_virtual_cursor_pos += _velocity * delta
	
	# Ограничение в пределах экрана
	var viewport_rect := get_viewport_rect()
	_virtual_cursor_pos.x = clamp(_virtual_cursor_pos.x, 0, viewport_rect.size.x)
	_virtual_cursor_pos.y = clamp(_virtual_cursor_pos.y, 0, viewport_rect.size.y)

func _get_stick_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("ui_cursor_right") - Input.get_action_strength("ui_cursor_left"),
		Input.get_action_strength("ui_cursor_down") - Input.get_action_strength("ui_cursor_up")
	)
