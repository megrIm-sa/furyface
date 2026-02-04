class_name FearComponent
extends Node

signal fear_entered(duration: float)
signal fear_exited()

@export_group("Fear Configuration")
@export var flee_speed_multiplier: float = 1.5
@export var fear_color: Color = Color(0.8, 0.6, 1.0, 1.0)
@export var shake_amount: float = 2.0

@export_group("Dependencies")
@export var movement: MovementComponent
@export var sprite: Sprite2D
@export var body: CharacterBody2D

var is_feared: bool = false
var fear_timer: float = 0.0
var fear_source_position: Vector2 = Vector2.ZERO

var original_modulate: Color = Color.WHITE
var color_tween: Tween

func _ready() -> void:
	if sprite:
		original_modulate = sprite.modulate

func _process(delta: float) -> void:
	if not is_feared:
		return
	
	fear_timer -= delta
	
	if fear_timer <= 0.0:
		exit_fear()
		return
	
	# Визуальные эффекты
	_process_fear_visuals()

func _physics_process(delta: float) -> void:
	if not is_feared or not movement or not body:
		return
	
	# Убегаем от источника страха
	var flee_direction = (body.global_position - fear_source_position).normalized()
	var flee_speed = movement.move_speed * flee_speed_multiplier
	
	body.velocity = body.velocity.move_toward(flee_direction * flee_speed, movement.acceleration * delta)

## Входит в состояние страха
func enter_fear(duration: float, source_position: Vector2) -> void:
	if is_feared:
		# Продлеваем страх
		fear_timer = max(fear_timer, duration)
		return
	
	is_feared = true
	fear_timer = duration
	fear_source_position = source_position
	
	_apply_fear_visual()
	fear_entered.emit(duration)

## Выходит из состояния страха
func exit_fear() -> void:
	if not is_feared:
		return
	
	is_feared = false
	fear_timer = 0.0
	
	_remove_fear_visual()
	fear_exited.emit()

## Проверяет, в страхе ли
func is_in_fear() -> bool:
	return is_feared

func _apply_fear_visual() -> void:
	"""Применяет визуальный эффект страха"""
	if not sprite:
		return
	
	if color_tween and color_tween.is_running():
		color_tween.kill()
	
	color_tween = create_tween()
	color_tween.tween_property(sprite, "modulate", fear_color, 0.2)

func _remove_fear_visual() -> void:
	"""Убирает визуальный эффект страха"""
	if not sprite:
		return
	
	# Сбрасываем offset
	sprite.offset = Vector2.ZERO
	
	if color_tween and color_tween.is_running():
		color_tween.kill()
	
	color_tween = create_tween()
	color_tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func _process_fear_visuals() -> void:
	"""Обрабатывает визуальные эффекты страха"""
	if not sprite:
		return
	
	# Дрожание спрайта
	var shake = Vector2(
		randf_range(-shake_amount, shake_amount),
		randf_range(-shake_amount, shake_amount)
	)
	sprite.offset = shake
