# res://scripts/weapons/revolver_visuals.gd
class_name RevolverVisuals
extends Node2D

signal shoot_animation_finished(is_left: bool)
signal reload_animation_finished()

@export var revolver_scene: PackedScene
@export var gun_offset: float = 8.0

# Параметры активного/неактивного револьвера
@export var active_offset: Vector2 = Vector2(0, 0)
@export var inactive_offset: Vector2 = Vector2(-12, 8)
@export var inactive_rotation: float = -25.0
@export var transition_speed: float = 12.0

var left_gun: Node2D
var right_gun: Node2D
var left_anim: AnimationPlayer
var right_anim: AnimationPlayer
var left_sprite: Sprite2D
var right_sprite: Sprite2D

var hands_controller: HandsController
var is_reloading: bool = false

# Текущее состояние
var left_is_active: bool = true
var target_left_offset: Vector2 = Vector2.ZERO
var target_right_offset: Vector2 = Vector2.ZERO
var target_left_rotation: float = 0.0
var target_right_rotation: float = 0.0
var current_left_offset: Vector2 = Vector2.ZERO
var current_right_offset: Vector2 = Vector2.ZERO
var current_left_rotation: float = 0.0
var current_right_rotation: float = 0.0

func _ready():
	_setup_guns()
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		hands_controller = player.get_node_or_null("Hands")
	
	_update_active_state(true)
	_play_idle()

func _setup_guns():
	if not revolver_scene:
		push_error("RevolverVisuals: revolver_scene not assigned!")
		return
	
	left_gun = revolver_scene.instantiate()
	left_gun.name = "LeftGun"
	add_child(left_gun)
	left_anim = left_gun.get_node("AnimationPlayer")
	left_sprite = left_gun.get_node("Sprite") as Sprite2D
	if left_anim:
		left_anim.animation_finished.connect(_on_left_animation_finished)
	
	right_gun = revolver_scene.instantiate()
	right_gun.name = "RightGun"
	add_child(right_gun)
	right_anim = right_gun.get_node("AnimationPlayer")
	right_sprite = right_gun.get_node("Sprite") as Sprite2D
	if right_anim:
		right_anim.animation_finished.connect(_on_right_animation_finished)

func _process(delta):
	if not hands_controller or not left_gun or not right_gun:
		return
	
	# Плавная интерполяция смещений и поворотов
	current_left_offset = current_left_offset.lerp(target_left_offset, transition_speed * delta)
	current_right_offset = current_right_offset.lerp(target_right_offset, transition_speed * delta)
	current_left_rotation = lerp_angle(current_left_rotation, target_left_rotation, transition_speed * delta)
	current_right_rotation = lerp_angle(current_right_rotation, target_right_rotation, transition_speed * delta)
	
	# Получаем позиции рук и базовый угол
	var left_hand_pos = hands_controller.get_node("LeftHand").global_position
	var right_hand_pos = hands_controller.get_node("RightHand").global_position
	var base_angle = hands_controller.get_hands_angle()
	
	# Применяем смещения с учетом поворота
	var left_offset_rotated = current_left_offset.rotated(base_angle)
	var right_offset_rotated = current_right_offset.rotated(base_angle)
	
	left_gun.global_position = left_hand_pos + left_offset_rotated
	right_gun.global_position = right_hand_pos + right_offset_rotated
	
	# Применяем повороты
	if left_is_active and not is_reloading:
		left_gun.rotation = _get_aim_angle_to_cursor(left_gun.global_position)
	else:
		left_gun.rotation = base_angle + current_left_rotation
	
	if not left_is_active and not is_reloading:
		right_gun.rotation = _get_aim_angle_to_cursor(right_gun.global_position)
	else:
		right_gun.rotation = base_angle + current_right_rotation
	
	# Flip
	_update_flip()

func _get_aim_angle_to_cursor(from_position: Vector2) -> float:
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - from_position).normalized()
	return direction.angle()

func _update_flip():
	if not hands_controller:
		return
	
	var direction = hands_controller.get_hands_direction()
	
	if direction.x < 0:
		if left_sprite:
			left_sprite.flip_v = true
		if right_sprite:
			right_sprite.flip_v = true
	else:
		if left_sprite:
			left_sprite.flip_v = false
		if right_sprite:
			right_sprite.flip_v = false

func set_active_gun(is_left: bool):
	if left_is_active == is_left and not is_reloading:
		return
	
	left_is_active = is_left
	_update_active_state(is_left)

func _update_active_state(left_active: bool):
	"""Обновляет визуальное состояние активного/неактивного револьвера"""
	if is_reloading:
		# При перезарядке ОБА револьвера в неактивном состоянии
		target_left_offset = inactive_offset
		target_right_offset = inactive_offset
		target_left_rotation = deg_to_rad(inactive_rotation)
		target_right_rotation = deg_to_rad(inactive_rotation)
		return
	
	if left_active:
		# Левый активен
		target_left_offset = active_offset
		target_left_rotation = 0.0
		
		# Правый неактивен
		target_right_offset = inactive_offset
		target_right_rotation = deg_to_rad(inactive_rotation)
	else:
		# Правый активен
		target_right_offset = active_offset
		target_right_rotation = 0.0
		
		# Левый неактивен
		target_left_offset = inactive_offset
		target_left_rotation = deg_to_rad(inactive_rotation)

func play_shoot_animation(use_left: bool):
	if is_reloading:
		return
	
	set_active_gun(!use_left)
	
	if use_left and left_anim:
		left_anim.play("shoot")
	elif not use_left and right_anim:
		right_anim.play("shoot")

func play_reload_animation():
	if is_reloading:
		return
	
	is_reloading = true
	
	# Оба револьвера переходят в неактивное состояние
	_update_active_state(true)  # left_active не важно, is_reloading = true
	
	# Запускаем анимацию перезарядки
	if left_anim:
		left_anim.play("reload")
	if right_anim:
		right_anim.play("reload")
	
	# Ждем завершения анимации
	if left_anim:
		await left_anim.animation_finished
	
	# ВАЖНО: сбрасываем флаг перезарядки ПЕРЕД обновлением состояния
	is_reloading = false
	
	# Возвращаем левый револьвер в активное состояние
	set_active_gun(true)
	
	# Возвращаемся к idle
	_play_idle()
	
	reload_animation_finished.emit()

func _play_idle():
	"""Проигрывает idle анимацию для обоих револьверов"""
	if left_anim and left_anim.has_animation("idle"):
		left_anim.play("idle")
	
	if right_anim and right_anim.has_animation("idle"):
		right_anim.play("idle")

func set_revolver_scene(scene: PackedScene):
	revolver_scene = scene
	
	if left_gun:
		left_gun.queue_free()
	if right_gun:
		right_gun.queue_free()
	
	_setup_guns()

func _on_left_animation_finished(anim_name: String):
	if anim_name == "shoot":
		if left_anim and left_anim.has_animation("idle"):
			left_anim.play("idle")
		shoot_animation_finished.emit(true)

func _on_right_animation_finished(anim_name: String):
	if anim_name == "shoot":
		if right_anim and right_anim.has_animation("idle"):
			right_anim.play("idle")
		shoot_animation_finished.emit(false)
