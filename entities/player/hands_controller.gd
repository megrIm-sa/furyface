class_name HandsController
extends Node2D

signal slash_started()
signal slash_finished()

@export_group("Configuration")
@export var hand_distance: float = 12.0
@export var hand_side_offset: float = 4.0
@export var smoothness: float = 15.0
@export var use_mouse_target: bool = true

@export_group("Slash Parameters")
@export var slash_windup_distance: float = -8.0
@export var slash_forward_distance: float = 16.0
@export var slash_side_distance: float = 6.0

@onready var right_hand: Marker2D = $RightHand
@onready var left_hand: Marker2D = $LeftHand

var target_direction: Vector2 = Vector2.RIGHT
var smooth_direction: Vector2 = Vector2.RIGHT
var current_angle: float = 0.0

var is_slashing: bool = false
var hand_offset: Vector2 = Vector2.ZERO
var slash_tween: Tween

func _process(delta: float) -> void:
	if use_mouse_target:
		var mouse_pos = get_global_mouse_position()
		target_direction = (mouse_pos - global_position).normalized()
	
	smooth_direction = smooth_direction.lerp(target_direction, smoothness * delta).normalized()
	current_angle = smooth_direction.angle()
	
	_update_hands_position(smooth_direction)
	_update_z_index(smooth_direction)

func set_target_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		target_direction = direction.normalized()

func set_direction_immediate(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		target_direction = direction.normalized()
		smooth_direction = target_direction
		current_angle = smooth_direction.angle()

func _update_hands_position(direction: Vector2) -> void:
	var main_position = direction * hand_distance + hand_offset
	var perpendicular = Vector2(-direction.y, direction.x)
	
	right_hand.position = main_position + perpendicular * hand_side_offset
	left_hand.position = main_position - perpendicular * hand_side_offset

func _update_z_index(direction: Vector2) -> void:
	if direction.y > 0.3:
		z_index = 1
	elif direction.y < -0.3:
		z_index = -1
	else:
		z_index = 0

func play_slash_animation(duration: float) -> void:
	if is_slashing:
		return
	
	is_slashing = true
	slash_started.emit()
	
	if slash_tween and slash_tween.is_valid():
		slash_tween.kill()
	
	var forward = smooth_direction
	var sideways = Vector2(-smooth_direction.y, smooth_direction.x)
	
	slash_tween = create_tween()
	slash_tween.set_ease(Tween.EASE_OUT)
	slash_tween.set_trans(Tween.TRANS_BACK)
	
	var windup_offset = forward * slash_windup_distance + sideways * slash_side_distance
	slash_tween.tween_property(self, "hand_offset", windup_offset, duration * 0.2)
	
	slash_tween.set_ease(Tween.EASE_IN)
	slash_tween.set_trans(Tween.TRANS_EXPO)
	var forward_offset = forward * slash_forward_distance
	slash_tween.tween_property(self, "hand_offset", forward_offset, duration * 0.3)
	
	slash_tween.set_ease(Tween.EASE_OUT)
	slash_tween.set_trans(Tween.TRANS_CIRC)
	slash_tween.tween_property(self, "hand_offset", Vector2.ZERO, duration * 0.5)
	
	await slash_tween.finished
	is_slashing = false
	hand_offset = Vector2.ZERO
	slash_finished.emit()

# ============= PUBLIC API =============

func get_primary_hand_position() -> Vector2:
	return right_hand.global_position

func get_left_hand_position() -> Vector2:
	"""Возвращает глобальную позицию левой руки"""
	return left_hand.global_position

func get_right_hand_position() -> Vector2:
	"""Возвращает глобальную позицию правой руки"""
	return right_hand.global_position

func get_hands_direction() -> Vector2:
	return smooth_direction

func get_hands_angle() -> float:
	return current_angle
