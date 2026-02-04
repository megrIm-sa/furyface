class_name EnemyAnimationController
extends Node

@export_group("Dependencies")
@export var anim_player: AnimationPlayer
@export var sprite: Sprite2D

@export_group("Animation Names")
@export var idle_anim: String = "idle"
@export var walk_anim: String = "walk"
@export var attack_anim: String = "attack"
@export var death_anim: String = "death"

@export_group("Settings")
@export var movement_threshold: float = 10.0

var current_state: String = ""
var is_manually_controlled: bool = false

func _ready() -> void:
	if not anim_player:
		push_warning("EnemyAnimationController: anim_player not assigned!")

## Проигрывает idle анимацию
func play_idle() -> void:
	_play_animation(idle_anim)

## Проигрывает walk анимацию
func play_walk() -> void:
	_play_animation(walk_anim)

## Проигрывает attack анимацию
func play_attack() -> void:
	_play_animation(attack_anim)

## Проигрывает death анимацию
func play_death() -> void:
	_play_animation(death_anim)
	is_manually_controlled = true

## Обновляет flip спрайта на основе направления
func update_flip(direction: Vector2) -> void:
	if not sprite or direction == Vector2.ZERO:
		return
	
	sprite.flip_h = direction.x < 0

## Обновляет анимацию на основе скорости
func update_animation_from_velocity(velocity: Vector2) -> void:
	if is_manually_controlled:
		return
	
	if velocity.length() > movement_threshold:
		play_walk()
	else:
		play_idle()

## Устанавливает паузу анимации и позицию (для beat-синхронизации)
func set_animation_position(anim_name: String, position: float) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)
	
	anim_player.pause()
	anim_player.seek(position, true)

## Продолжает анимацию с указанной позиции
func resume_animation_from(anim_name: String, position: float) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	
	anim_player.play(anim_name)
	anim_player.seek(position, true)

func _play_animation(anim_name: String) -> void:
	"""Внутренний метод для проигрывания анимации"""
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	
	if anim_player.current_animation != anim_name:
		current_state = anim_name
		anim_player.play(anim_name)
