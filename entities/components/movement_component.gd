class_name MovementComponent
extends Node

signal movement_state_changed(is_moving: bool)

@export var move_speed: float = 100.0
@export var acceleration: float = 5000.0
@export var friction: float = 5000.0

var is_enabled: bool = true

## Применяет движение к CharacterBody2D родителю
func apply_movement(body: CharacterBody2D, direction: Vector2, delta: float) -> void:
	if not is_enabled:
		return
	
	if direction != Vector2.ZERO:
		body.velocity = body.velocity.move_toward(
			direction.normalized() * move_speed,
			acceleration * delta
		)
	else:
		stop_movement(body, delta)

## Останавливает движение с применением трения
func stop_movement(body: CharacterBody2D, delta: float) -> void:
	body.velocity = body.velocity.move_toward(Vector2.ZERO, friction * delta)

## Проверяет, движется ли тело
func is_moving(body: CharacterBody2D, threshold: float = 10.0) -> bool:
	return body.velocity.length() >= threshold

## Мгновенно останавливает движение
func halt(body: CharacterBody2D) -> void:
	body.velocity = Vector2.ZERO

## Включает/выключает компонент
func set_enabled(enabled: bool) -> void:
	is_enabled = enabled
