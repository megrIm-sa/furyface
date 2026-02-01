# res://scripts/weapons/revolver_visuals.gd
class_name RevolverVisuals
extends Node2D

signal shoot_animation_finished(is_left: bool)
signal reload_animation_finished()

@export var revolver_scene: PackedScene

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

func _ready():
	_setup_guns()
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		hands_controller = player.get_node_or_null("Hands")
	
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

func _process(_delta):
	if not hands_controller or not left_gun or not right_gun:
		return
	
	# Получаем позиции рук и базовый угол
	var left_hand_pos = hands_controller.get_node("LeftHand").global_position
	var right_hand_pos = hands_controller.get_node("RightHand").global_position
	var base_angle = hands_controller.get_hands_angle()
	
	# Просто позиционируем револьверы на руках
	left_gun.global_position = left_hand_pos
	right_gun.global_position = right_hand_pos
	
	# Применяем повороты
	if left_is_active and not is_reloading:
		# Активный револьвер целится в курсор
		left_gun.rotation = _get_aim_angle_to_cursor(left_gun.global_position)
	else:
		# Неактивный следует базовому углу рук
		# AnimationPlayer может добавить свой rotation поверх
		left_gun.rotation = base_angle
	
	if not left_is_active and not is_reloading:
		# Активный револьвер целится в курсор
		right_gun.rotation = _get_aim_angle_to_cursor(right_gun.global_position)
	else:
		# Неактивный следует базовому углу рук
		right_gun.rotation = base_angle
	
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
	var looking_left : bool= direction.x < 0
	
	if left_sprite:
		left_sprite.flip_v = looking_left
		#left_sprite.offset = Vector2(-24, -6) if looking_left else Vector2(24, -6)
	
	if right_sprite:
		right_sprite.flip_v = looking_left
		#right_sprite.offset = Vector2(-24, -6) if looking_left else Vector2(24, -6)


func set_active_gun(is_left: bool):
	"""Переключает активный револьвер"""
	if left_is_active == is_left and not is_reloading:
		return
	
	left_is_active = is_left

func play_shoot_animation(use_left: bool):
	if is_reloading:
		return
	
	# Переключаем активный револьвер
	set_active_gun(!use_left)
	
	# Проигрываем анимацию выстрела
	if use_left and left_anim:
		left_anim.play("shoot")
	elif not use_left and right_anim:
		right_anim.play("shoot")

func play_reload_animation():
	if is_reloading:
		return
	
	is_reloading = true
	
	# Запускаем анимацию перезарядки
	if left_anim:
		left_anim.play("reload")
	if right_anim:
		right_anim.play("reload")
	
	# Ждем завершения анимации
	if left_anim:
		await left_anim.animation_finished
	
	# Сбрасываем флаг перезарядки
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
