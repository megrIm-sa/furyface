class_name MeleeAttackComponent
extends Node

signal attack_started()
signal windup_beat(beats_passed: int, total_beats: int)
signal attack_executed()
signal attack_hit(target: Node2D, damage: float)

@export_group("Attack Configuration")
@export var attack_range: float = 50.0
@export var damage: float = 10.0
@export var windup_beats: int = 3
@export var knockback_force: float = 150.0

@export_group("Dependencies")
@export var telegraph_visualizer: AttackTelegraphVisualizer
@export var shockwave_visualizer: ShockwaveVisualizer

var is_attacking: bool = false
var windup_start_beat: int = -1
var beats_elapsed: int = 0
var is_attack_executed: bool = false  # ИСПРАВЛЕНО: единообразное имя

## Пытается начать атаку
func try_start_attack() -> bool:
	if is_attacking:
		return false
	
	is_attacking = true
	windup_start_beat = -1
	beats_elapsed = 0
	is_attack_executed = false
	
	if telegraph_visualizer:
		telegraph_visualizer.show_telegraph(attack_range, windup_beats)
	
	attack_started.emit()
	print("[MeleeAttack] Attack started")
	return true

## Обрабатывает бит во время атаки
func process_beat(beat_number: int) -> void:
	if not is_attacking:
		return
	
	# Устанавливаем стартовый бит
	if windup_start_beat == -1:
		windup_start_beat = beat_number
		beats_elapsed = 0
		print("[MeleeAttack] Windup started on beat %d" % beat_number)
	else:
		beats_elapsed = beat_number - windup_start_beat
	
	print("[MeleeAttack] Beat %d, elapsed: %d/%d" % [beat_number, beats_elapsed, windup_beats])
	
	# Обновляем телеграф
	if telegraph_visualizer:
		telegraph_visualizer.update_windup_progress(beats_elapsed, windup_beats)
	
	windup_beat.emit(beats_elapsed, windup_beats)
	
	# ИСПРАВЛЕНО: правильное имя переменной
	if beats_elapsed >= windup_beats and not is_attack_executed:
		print("[MeleeAttack] Executing attack!")
		_execute_attack()

func _execute_attack() -> void:
	"""Выполняет удар"""
	is_attack_executed = true
	
	# Скрываем телеграф
	if telegraph_visualizer:
		telegraph_visualizer.hide_telegraph()
	
	# Показываем шоквейв
	if shockwave_visualizer:
		shockwave_visualizer.play_shockwave(attack_range)
	
	# Проверяем попадания
	_check_circular_hit()
	
	attack_executed.emit()
	print("[MeleeAttack] Attack executed!")

func _check_circular_hit() -> void:
	"""Проверяет попадание в круговой области"""
	var space_state = get_parent().get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var shape = CircleShape2D.new()
	shape.radius = attack_range
	query.shape = shape
	query.transform = Transform2D(0, get_parent().global_position)
	query.collision_mask = 1  # Player layer
	query.exclude = [get_parent().get_rid()]
	
	var results = space_state.intersect_shape(query, 32)
	
	print("[MeleeAttack] Checking hits, found %d colliders" % results.size())
	
	for result in results:
		var body = result.collider
		
		# ИСПРАВЛЕНО: ищем HealthComponent
		var health_component: HealthComponent = null
		
		if body.has_node("HealthComponent"):
			health_component = body.get_node("HealthComponent")
		elif body.get_parent() and body.get_parent().has_node("HealthComponent"):
			health_component = body.get_parent().get_node("HealthComponent")
		
		if health_component and not health_component.is_invulnerable:
			var knockback_dir = (body.global_position - get_parent().global_position).normalized()
			var knockback_vel = knockback_dir * knockback_force
			
			health_component.take_damage(damage, get_parent().global_position, knockback_vel)
			attack_hit.emit(body, damage)
			
			print("[MeleeAttack] Hit target for %s damage" % damage)

## Завершает атаку
func finish_attack() -> void:
	is_attacking = false
	windup_start_beat = -1
	beats_elapsed = 0
	is_attack_executed = false
	
	if telegraph_visualizer:
		telegraph_visualizer.hide_telegraph()
	
	print("[MeleeAttack] Attack finished")

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
	
	print("[MeleeAttack] Attack cancelled")
