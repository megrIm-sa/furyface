class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damage_taken(amount: float, source_position: Vector2, knockback_direction: Vector2)
signal died()
signal resurrected()

@export var max_health: float = 100.0
@export var start_invulnerable: bool = false

var current_health: float
var is_invulnerable: bool = false
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	is_invulnerable = start_invulnerable
	
	# Emit после создания сцены чтобы UI успел подключиться
	await get_tree().process_frame
	health_changed.emit(current_health, max_health)

## Наносит урон. Возвращает true если сущность умерла.
func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, knockback_direction: Vector2 = Vector2.ZERO) -> bool:
	if is_invulnerable or is_dead:
		return false
	
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	damage_taken.emit(amount, source_position, knockback_direction)
	
	if current_health <= 0.0 and not is_dead:
		die()
		return true
	
	return false

## Восстанавливает здоровье
func heal(amount: float) -> void:
	if is_dead:
		return
	
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

## Убивает сущность
func die() -> void:
	if is_dead:
		return
	
	is_dead = true
	died.emit()

## Воскрешает сущность
func resurrect(health_amount: float = -1.0) -> void:
	if not is_dead:
		return
	
	is_dead = false
	current_health = health_amount if health_amount > 0.0 else max_health
	health_changed.emit(current_health, max_health)
	resurrected.emit()

## Делает неуязвимым на указанное время (0 = бесконечно)
func set_invulnerable(duration: float = 0.0) -> void:
	is_invulnerable = true
	
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		is_invulnerable = false

## Снимает неуязвимость
func remove_invulnerability() -> void:
	is_invulnerable = false

## Возвращает процент здоровья (0.0 - 1.0)
func get_health_percent() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0

## Проверяет, полное ли здоровье
func is_at_full_health() -> bool:
	return current_health >= max_health
