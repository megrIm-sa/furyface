class_name BladeVisuals
extends Node2D

signal animation_finished()

@export_group("Animation Configuration")
@export var slash_duration: float = 0.12
@export var slash_angle: float = 110.0
@export var windup_angle: float = -50.0
@export var hand_windup_offset: Vector2 = Vector2(-8, 2)
@export var hand_strike_offset: Vector2 = Vector2(12, -3)
@export var flip_offset_y: float = 10.0

@export_group("Dependencies")
@export var sprite: Sprite2D
@export var hands_controller: HandsController

var attack_tween: Tween
var is_flipped: bool = false
var hand_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not sprite:
		push_error("BladeVisuals: sprite not assigned!")
		return
	
	if not hands_controller:
		push_warning("BladeVisuals: hands_controller not assigned!")

func _process(_delta: float) -> void:
	if not hands_controller or not sprite:
		return
	
	var direction = hands_controller.get_hands_direction()
	var base_angle = hands_controller.get_hands_angle()
	
	rotation = base_angle
	
	# Позиционируем относительно руки
	var base_hand_position = hands_controller.get_primary_hand_position()
	var offset_rotated = hand_offset.rotated(base_angle)
	global_position = base_hand_position + offset_rotated
	
	# Обновляем flip
	_update_sprite_flip(direction)

func _update_sprite_flip(direction: Vector2) -> void:
	"""Обновляет flip спрайта в зависимости от направления"""
	if direction.x < 0:
		sprite.flip_v = true
		is_flipped = true
		sprite.offset.y = flip_offset_y
	else:
		sprite.flip_v = false
		is_flipped = false
		sprite.offset.y = -flip_offset_y

func play_attack_animation() -> void:
	"""Проигрывает анимацию атаки мечом"""
	# Останавливаем предыдущую анимацию
	if attack_tween and attack_tween.is_valid():
		attack_tween.kill()
	
	# Настраиваем параметры в зависимости от flip
	var anim_windup = windup_angle
	var anim_slash = slash_angle
	var hand_windup = hand_windup_offset
	var hand_strike = hand_strike_offset
	
	if is_flipped:
		anim_windup = -windup_angle
		anim_slash = -slash_angle
		hand_windup.x = -hand_windup.x
		hand_strike.x = -hand_strike.x
	
	# Сбрасываем начальное состояние
	sprite.rotation = 0.0
	hand_offset = Vector2.ZERO
	
	attack_tween = create_tween()
	attack_tween.set_parallel(false)
	
	# ФАЗА 1: ЗАМАХ (30% времени)
	attack_tween.set_ease(Tween.EASE_OUT)
	attack_tween.set_trans(Tween.TRANS_CUBIC)
	
	attack_tween.tween_property(sprite, "rotation", deg_to_rad(anim_windup), slash_duration * 0.3)
	attack_tween.parallel().tween_property(self, "hand_offset", hand_windup, slash_duration * 0.3)
	
	# ФАЗА 2: УДАР (25% времени)
	attack_tween.set_ease(Tween.EASE_IN)
	attack_tween.set_trans(Tween.TRANS_EXPO)
	
	attack_tween.tween_property(sprite, "rotation", deg_to_rad(anim_slash), slash_duration * 0.25)
	attack_tween.parallel().tween_property(self, "hand_offset", hand_strike, slash_duration * 0.25)
	
	# ФАЗА 3: ВОЗВРАТ (45% времени)
	attack_tween.set_ease(Tween.EASE_OUT)
	attack_tween.set_trans(Tween.TRANS_BACK)
	
	attack_tween.tween_property(sprite, "rotation", 0.0, slash_duration * 0.45)
	attack_tween.parallel().tween_property(self, "hand_offset", Vector2.ZERO, slash_duration * 0.45)
	
	await attack_tween.finished
	
	# Сбрасываем состояние после анимации
	sprite.rotation = 0.0
	hand_offset = Vector2.ZERO
	animation_finished.emit()
