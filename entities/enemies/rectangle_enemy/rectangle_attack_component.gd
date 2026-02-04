class_name RectangleAttackComponent
extends Node

signal attack_started(direction: Vector2)
signal windup_beat(beats_passed: int, total_beats: int)
signal attack_executed()
signal attack_hit(target: Node2D, damage: float)

@export_group("Attack Configuration")
@export var attack_length: float = 100.0
@export var attack_width: float = 40.0
@export var damage: float = 10.0
@export var windup_beats: int = 3
@export var knockback_force: float = 150.0

@export_group("Dependencies")
@export var telegraph_visualizer: RectangleTelegraphVisualizer
@export var shockwave_visualizer: RectangleShockwaveVisualizer

var is_attacking: bool = false
var windup_start_beat: int = -1
var beats_elapsed: int = 0
var is_attack_executed: bool = false  # ИСПРАВЛЕНО: единообразное имя
var attack_direction: Vector2 = Vector2.RIGHT

## Пытается начать атаку в указанном направлении
func try_start_attack(direction: Vector2) -> bool:
	if is_attacking:
		return false
	
	is_attacking = true
	windup_start_beat = -1
	beats_elapsed = 0
	is_attack_executed = false
	attack_direction = direction.normalized()
	
	if telegraph_visualizer:
		telegraph_visualizer.show_telegraph(attack_length, attack_width, attack_direction, windup_beats)
	
	attack_started.emit(attack_direction)
	print("[RectangleAttack] Attack started, direction: %s" % attack_direction)
	return true

## Обрабатывает бит во время атаки
func process_beat(beat_number: int) -> void:
	if not is_attacking:
		return
	
	# Устанавливаем стартовый бит
	if windup_start_beat == -1:
		windup_start_beat = beat_number
		beats_elapsed = 0
		print("[RectangleAttack] Windup started on beat %d" % beat_number)
	else:
		beats_elapsed = beat_number - windup_start_beat
	
	print("[RectangleAttack] Beat %d, elapsed: %d/%d" % [beat_number, beats_elapsed, windup_beats])
	
	# Обновляем телеграф
	if telegraph_visualizer:
		telegraph_visualizer.update_windup_progress(beats_elapsed, windup_beats)
	
	windup_beat.emit(beats_elapsed, windup_beats)
	
	# ИСПРАВЛЕНО: правильное имя переменной
	if beats_elapsed >= windup_beats and not is_attack_executed:
		print("[RectangleAttack] Executing attack!")
		_execute_attack()

func _execute_attack() -> void:
	"""Выполняет удар"""
	is_attack_executed = true
	
	# Скрываем телеграф
	if telegraph_visualizer:
		telegraph_visualizer.hide_telegraph()
	
	# Показываем шоквейв
	if shockwave_visualizer:
		shockwave_visualizer.play_shockwave(attack_length, attack_width, attack_direction)
	
	# Проверяем попадания
	_check_rectangle_hit()
	
	attack_executed.emit()
	print("[RectangleAttack] Attack executed!")

func _check_rectangle_hit() -> void:
	"""Проверяет попадание в прямоугольной области"""
	var space_state = get_parent().get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Создаём прямоугольник атаки
	var shape = RectangleShape2D.new()
	shape.size = Vector2(attack_length, attack_width)
	query.shape = shape
	
	# Угол направления атаки
	var angle = attack_direction.angle()
	
	# Центр прямоугольника смещен на половину длины вперед
	var center_offset = attack_direction * (attack_length * 0.5)
	
	query.transform = Transform2D(angle, get_parent().global_position + center_offset)
	query.collision_mask = 1  # Player layer
	query.exclude = [get_parent().get_rid()]
	
	var results = space_state.intersect_shape(query, 32)
	
	print("[RectangleAttack] Checking hits, found %d colliders" % results.size())
	
	for result in results:
		var body = result.collider
		
		var health_component: HealthComponent = null
		
		if body.has_node("HealthComponent"):
			health_component = body.get_node("HealthComponent")
		elif body.get_parent() and body.get_parent().has_node("HealthComponent"):
			health_component = body.get_parent().get_node("HealthComponent")
		
		if health_component and not health_component.is_invulnerable:
			var knockback_dir = attack_direction
			var knockback_vel = knockback_dir * knockback_force
			
			health_component.take_damage(damage, get_parent().global_position, knockback_vel)
			attack_hit.emit(body, damage)
			
			print("[RectangleAttack] Hit target for %s damage" % damage)

## Завершает атаку
func finish_attack() -> void:
	is_attacking = false
	windup_start_beat = -1
	beats_elapsed = 0
	is_attack_executed = false
	
	if telegraph_visualizer:
		telegraph_visualizer.hide_telegraph()
	
	print("[RectangleAttack] Attack finished")

## Проверяет, можно ли атаковать
func can_attack() -> bool:
	return not is_attacking

## Отменяет атаку
func cancel_attack() -> void:
	if telegraph_visualizer:
		telegraph_visualizer.hide_telegraph()
	
	is_attacking = false
	windup_start_beat = -1
	beats_elapsed = 0
	is_attack_executed = false
	
	print("[RectangleAttack] Attack cancelled")

## Возвращает направление атаки
func get_attack_direction() -> Vector2:
	return attack_direction
