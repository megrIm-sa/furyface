class_name PlayerAnimationController
extends Node

@export var sprite: Sprite2D
@export var mask_sprite: Sprite2D
@export var animation_player: AnimationPlayer

@export_group("Animation Settings")
@export var walk_backwards_threshold: float = -0.3
@export var dash_speed_scale: float = 2.0

var facing_direction: Vector2 = Vector2.RIGHT

## Обновляет facing к целевой позиции (например, к курсору)
func update_facing_to_position(from: Vector2, to: Vector2) -> void:
	facing_direction = (to - from).normalized()
	if facing_direction == Vector2.ZERO:
		facing_direction = Vector2.RIGHT

## Обновляет facing в направлении вектора
func update_facing_to_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		facing_direction = direction.normalized()

## Обновляет flip спрайтов на основе facing
func update_sprite_flip() -> void:
	if facing_direction.x == 0:
		return
	
	var should_flip = facing_direction.x < 0
	
	if sprite:
		sprite.flip_h = should_flip
	
	if mask_sprite:
		mask_sprite.flip_h = should_flip

## Проигрывает анимацию на основе состояния
func play_state_animation(state_name: String, velocity: Vector2) -> void:
	if not animation_player:
		return
	
	match state_name:
		"idle":
			_play_animation("idle", 1.0)
		
		"walk":
			_play_animation("walk", 1.0)
			
			# Проверяем движение назад
			if _is_walking_backwards(velocity):
				animation_player.speed_scale = -1.0
			else:
				animation_player.speed_scale = 1.0
		
		"dash":
			# Пытаемся проиграть dash анимацию, иначе walk на высокой скорости
			if animation_player.has_animation("dash"):
				_play_animation("dash", 1.0)
			else:
				_play_animation("walk", dash_speed_scale)
		
		"dead":
			_play_animation("death", 1.0)

## Проигрывает конкретную анимацию
func play_animation(anim_name: String, speed: float = 1.0) -> void:
	_play_animation(anim_name, speed)

func _play_animation(anim_name: String, speed: float) -> void:
	if not animation_player:
		return
	
	if not animation_player.has_animation(anim_name):
		return
	
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
	
	animation_player.speed_scale = speed

func _is_walking_backwards(velocity: Vector2) -> bool:
	if velocity.length() < 10.0:
		return false
	
	var movement_dir = velocity.normalized()
	var dot = movement_dir.dot(facing_direction)
	
	return dot < walk_backwards_threshold
