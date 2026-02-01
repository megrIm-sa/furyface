# res://scripts/enemies/boss.gd
class_name Boss
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal phase_changed(new_phase: int)
signal died()
signal attack_pattern_started(pattern_name: String)
signal attack_pattern_finished(pattern_name: String)

@export var boss_name: String = "Unknown Boss"
@export var max_health: float = 1000.0
@export var move_speed: float = 150.0
@export var phase_2_health_threshold: float = 0.5  # 50% здоровья

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var collision: CollisionShape2D = $CollisionShape2D

var current_health: float
var current_phase: int = 1
var target: Player = null
var conductor: Conductor = null

var current_beat: float = 0.0
var last_beat: int = -1

var is_invulnerable: bool = false
var is_dead: bool = false
var is_performing_pattern: bool = false

func _ready():
	current_health = max_health
	add_to_group("boss")
	add_to_group("enemy")  # Для получения урона от оружия
	
	_find_dependencies()
	_on_ready()
	
	health_changed.emit(current_health, max_health)

func _find_dependencies():
	conductor = get_tree().get_first_node_in_group("conductor")
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func _physics_process(delta):
	if is_dead:
		return
	
	if conductor:
		current_beat = conductor.get_current_beat()
		var current_beat_int = int(floor(current_beat))
		
		if current_beat_int != last_beat:
			_on_beat(current_beat_int)
			last_beat = current_beat_int
	
	_process_boss(delta)
	move_and_slide()
	_update_visuals()

func _process_boss(delta: float):
	"""Переопределите в дочернем классе"""
	pass

func _on_beat(beat: int):
	"""Переопределите в дочернем классе"""
	pass

func _on_ready():
	"""Переопределите в дочернем классе"""
	pass

# ============= HEALTH SYSTEM =============

func take_damage(amount: float, source_position: Vector2, knockback_direction: Vector2 = Vector2.ZERO):
	if is_invulnerable or is_dead:
		return
	
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	_on_damage_taken(amount, source_position)
	_flash_sprite()
	
	# Проверка смены фазы
	var health_percent = current_health / max_health
	if current_phase == 1 and health_percent <= phase_2_health_threshold:
		_enter_phase_2()
	
	if current_health <= 0:
		_die()

func _on_damage_taken(amount: float, source_position: Vector2):
	"""Переопределите для реакции на урон"""
	pass

func _enter_phase_2():
	"""Переход во вторую фазу"""
	current_phase = 2
	is_invulnerable = true
	phase_changed.emit(2)
	_on_phase_2_enter()
	
	# Короткая неуязвимость при смене фазы
	await get_tree().create_timer(2.0).timeout
	is_invulnerable = false

func _on_phase_2_enter():
	"""Переопределите для кастомной логики второй фазы"""
	pass

func _die():
	if is_dead:
		return
	
	is_dead = true
	is_invulnerable = true
	died.emit()
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	_on_death()

func _on_death():
	"""Переопределите для кастомной логики смерти"""
	if anim and anim.has_animation("death"):
		anim.play("death")
		await anim.animation_finished
	
	await get_tree().create_timer(1.0).timeout
	queue_free()

# ============= UTILITIES =============

func get_distance_to_target() -> float:
	if not target:
		return INF
	return global_position.distance_to(target.global_position)

func get_direction_to_target() -> Vector2:
	if not target:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()

func get_beat_progress() -> float:
	return current_beat - floor(current_beat)

func is_near_beat(threshold: float = 0.1) -> bool:
	var progress = get_beat_progress()
	return progress < threshold or progress > (1.0 - threshold)

func wait_for_next_beat() -> void:
	var current_beat_int = int(floor(current_beat))
	while int(floor(current_beat)) == current_beat_int:
		await get_tree().process_frame

func _update_visuals():
	if not target or not sprite:
		return
	
	var to_target = target.global_position - global_position
	sprite.flip_h = to_target.x < 0

func _flash_sprite():
	if not sprite:
		return
	
	var original_modulate = sprite.modulate
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.15)
