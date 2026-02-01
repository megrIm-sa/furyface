# res://scripts/player/hands_controller.gd
class_name HandsController
extends Node2D

signal slash_started()
signal slash_finished()

@export var player: Player
@export var hand_distance: float = 12.0
@export var hand_side_offset: float = 4.0
@export var smoothness: float = 15.0

# Параметры взмаха
@export var slash_windup_distance: float = -8.0  # Отведение руки назад
@export var slash_forward_distance: float = 16.0  # Выпад вперёд
@export var slash_side_distance: float = 6.0  # Боковое движение

@onready var right_hand: Marker2D = $RightHand
@onready var left_hand: Marker2D = $LeftHand

var target_direction: Vector2 = Vector2.RIGHT
var smooth_direction: Vector2 = Vector2.RIGHT
var current_angle: float = 0.0

var is_slashing: bool = false
var hand_offset: Vector2 = Vector2.ZERO
var slash_tween: Tween

func _ready():
	if not player:
		player = get_parent() as Player

func _process(delta):
	if not player:
		return
	
	var mouse_pos = get_global_mouse_position()
	target_direction = (mouse_pos - global_position).normalized()
	smooth_direction = smooth_direction.lerp(target_direction, smoothness * delta).normalized()
	current_angle = smooth_direction.angle()
	
	_update_hands_position(smooth_direction)
	_update_z_index(smooth_direction)

func _update_hands_position(direction: Vector2):
	# Основная позиция руки в направлении курсора
	var main_position = direction * hand_distance
	
	# Перпендикулярный вектор для бокового смещения
	var perpendicular = Vector2(-direction.y, direction.x)
	
	# Правая рука немного правее от направления
	right_hand.position = main_position + perpendicular * hand_side_offset
	
	# Левая рука немного левее
	left_hand.position = main_position - perpendicular * hand_side_offset

func _update_z_index(direction: Vector2):
	if direction.y > 0.3:
		z_index = 1
	elif direction.y < -0.3:
		z_index = -1
	else:
		z_index = 0

func play_slash_animation(duration: float):
	"""Анимация движения руки при взмахе"""
	if is_slashing:
		return
	
	is_slashing = true
	slash_started.emit()
	
	# Останавливаем предыдущую анимацию
	if slash_tween and slash_tween.is_valid():
		slash_tween.kill()
	
	# Направление взмаха
	var forward = smooth_direction
	var sideways = Vector2(-smooth_direction.y, smooth_direction.x)
	
	slash_tween = create_tween()
	slash_tween.set_ease(Tween.EASE_OUT)
	slash_tween.set_trans(Tween.TRANS_BACK)
	
	# Фаза 1: Замах назад и в сторону (20% времени)
	var windup_offset = forward * slash_windup_distance + sideways * slash_side_distance
	slash_tween.tween_property(
		self,
		"hand_offset",
		windup_offset,
		duration * 0.2
	)
	
	# Фаза 2: Резкий выпад вперёд (30% времени)
	slash_tween.set_ease(Tween.EASE_IN)
	slash_tween.set_trans(Tween.TRANS_EXPO)  # Экспоненциальное ускорение
	var forward_offset = forward * slash_forward_distance
	slash_tween.tween_property(
		self,
		"hand_offset",
		forward_offset,
		duration * 0.3
	)
	
	# Фаза 3: Возврат (50% времени)
	slash_tween.set_ease(Tween.EASE_OUT)
	slash_tween.set_trans(Tween.TRANS_CIRC)
	slash_tween.tween_property(
		self,
		"hand_offset",
		Vector2.ZERO,
		duration * 0.5
	)
	
	await slash_tween.finished
	is_slashing = false
	hand_offset = Vector2.ZERO
	slash_finished.emit()

func get_primary_hand_position() -> Vector2:
	return right_hand.global_position

func get_hands_direction() -> Vector2:
	return smooth_direction

func get_hands_angle() -> float:
	return current_angle
