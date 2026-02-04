class_name TargetingComponent
extends Node

signal target_acquired(target: Node2D)
signal target_lost()
signal target_in_detection_range()
signal target_in_attack_range()

@export var detection_range: float = 200.0
@export var attack_range: float = 50.0
@export var target_group: String = "player"
@export var lose_target_multiplier: float = 1.5

var current_target: Node2D = null
var was_in_detection_range: bool = false
var was_in_attack_range: bool = false

func _physics_process(_delta: float) -> void:
	_update_target()
	_check_range_events()

func _update_target() -> void:
	"""Обновляет текущую цель"""
	# Проверяем валидность текущей цели
	if current_target and not is_instance_valid(current_target):
		_lose_target()
		return
	
	# Если цель потеряна, ищем новую
	if not current_target:
		_find_target()
		return
	
	# Проверяем, не вышла ли цель за пределы lose range
	var distance = get_distance_to_target()
	if distance > detection_range * lose_target_multiplier:
		_lose_target()

func _find_target() -> void:
	"""Ищет ближайшую цель в группе"""
	var targets = get_tree().get_nodes_in_group(target_group)
	if targets.is_empty():
		return
	
	var parent_pos = get_parent().global_position
	var closest_target: Node2D = null
	var closest_distance: float = INF
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		var dist = parent_pos.distance_to(target.global_position)
		if dist < detection_range and dist < closest_distance:
			closest_target = target
			closest_distance = dist
	
	if closest_target:
		current_target = closest_target
		target_acquired.emit(current_target)

func _lose_target() -> void:
	"""Теряет текущую цель"""
	current_target = null
	was_in_detection_range = false
	was_in_attack_range = false
	target_lost.emit()

func _check_range_events() -> void:
	"""Проверяет события входа/выхода из зон"""
	if not current_target:
		return
	
	var in_detection = is_target_in_detection_range()
	var in_attack = is_target_in_attack_range()
	
	# События detection range
	if in_detection and not was_in_detection_range:
		target_in_detection_range.emit()
	
	# События attack range
	if in_attack and not was_in_attack_range:
		target_in_attack_range.emit()
	
	was_in_detection_range = in_detection
	was_in_attack_range = in_attack

## Возвращает текущую цель
func get_target() -> Node2D:
	return current_target

## Проверяет наличие цели
func has_target() -> bool:
	return current_target != null and is_instance_valid(current_target)

## Возвращает дистанцию до цели
func get_distance_to_target() -> float:
	if not has_target():
		return INF
	return get_parent().global_position.distance_to(current_target.global_position)

## Возвращает направление к цели
func get_direction_to_target() -> Vector2:
	if not has_target():
		return Vector2.ZERO
	return (current_target.global_position - get_parent().global_position).normalized()

## Возвращает позицию цели
func get_target_position() -> Vector2:
	if not has_target():
		return get_parent().global_position
	return current_target.global_position

## Проверяет, в зоне ли обнаружения
func is_target_in_detection_range() -> bool:
	return get_distance_to_target() <= detection_range

## Проверяет, в зоне ли атаки
func is_target_in_attack_range() -> bool:
	return get_distance_to_target() <= attack_range

## Принудительно устанавливает цель
func set_target(target: Node2D) -> void:
	if current_target != target:
		current_target = target
		if target:
			target_acquired.emit(target)
		else:
			target_lost.emit()
