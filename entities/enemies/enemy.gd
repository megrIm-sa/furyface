# res://scripts/enemies/enemy.gd
class_name Enemy
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died()
signal attack_started()
signal attack_hit(target: Node2D, damage: float)

@export var enemy_data: EnemyResource

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

var current_health: float
var target: Player = null
var conductor: Conductor = null
var note_manager: NoteManager = null

var current_beat: float = 0.0
var last_beat: int = -1

enum State { IDLE, CHASE, ATTACK_WINDUP, ATTACK_STRIKE, STUNNED, FEAR, DEAD }  # ДОБАВЛЕНО FEAR
var state: State = State.IDLE
var previous_state: State = State.IDLE  # Для возврата из страха

# === FEAR SYSTEM ===
var is_feared: bool = false
var fear_timer: float = 0.0
var fear_direction: Vector2 = Vector2.ZERO

var is_invulnerable: bool = false

func _ready():
	if not enemy_data:
		push_error("Enemy requires enemy_data resource!")
		return
	
	current_health = enemy_data.max_health
	add_to_group("enemy")  # Важно для детекции FearMask
	
	# Применяем визуальные настройки
	if enemy_data.sprite and sprite:
		sprite.texture = enemy_data.sprite
	if sprite:
		sprite.scale = Vector2.ONE * enemy_data.scale_size
	
	_find_dependencies()
	_on_ready()

func _find_dependencies():
	conductor = get_tree().get_first_node_in_group("conductor")
	note_manager = get_tree().get_first_node_in_group("note_manager")
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func _physics_process(delta):
	if state == State.DEAD:
		return
	
	if conductor:
		current_beat = conductor.get_current_beat()
		var current_beat_int = int(floor(current_beat))
		
		if current_beat_int != last_beat:
			_on_beat(current_beat_int)
			last_beat = current_beat_int
	
	_process_state(delta)
	move_and_slide()
	_update_visuals()

func _process_state(delta: float):
	"""Переопределите этот метод в дочерних классах для обработки состояний"""
	match state:
		State.FEAR:
			_state_fear(delta)
		# Остальные состояния обрабатываются в дочерних классах

func _on_beat(beat: int):
	pass

func _on_ready():
	pass

# ============= FEAR SYSTEM =============

func enter_fear_state(duration: float):
	"""Входит в состояние страха"""
	# Не входим в страх если мертвы или уже атакуем
	if state == State.DEAD:
		return
	
	if is_attacking():
		print("[Enemy %s] Is attacking, cannot enter fear state" % name)
		return
	
	if is_feared:
		# Уже в страхе, просто обновляем таймер
		fear_timer = max(fear_timer, duration)
		return
	
	# Сохраняем текущее состояние для возврата
	if state != State.FEAR:
		previous_state = state
	
	is_feared = true
	fear_timer = duration
	change_state(State.FEAR)
	
	# Вычисляем направление убегания (от игрока)
	if target:
		fear_direction = (global_position - target.global_position).normalized()
	else:
		fear_direction = Vector2.RIGHT  # Fallback направление
	
	_on_fear_entered()
	print("[Enemy %s] Entered FEAR state for %.1fs" % [name, duration])

func exit_fear_state():
	"""Выходит из состояния страха"""
	if not is_feared:
		return
	
	is_feared = false
	fear_timer = 0.0
	
	# Возвращаемся к предыдущему состоянию
	if state == State.FEAR:
		change_state(previous_state if previous_state != State.FEAR else State.IDLE)
	
	_on_fear_exited()
	print("[Enemy %s] Exited FEAR state" % name)

func is_attacking() -> bool:
	"""Проверяет, находится ли враг в состоянии атаки"""
	return state in [State.ATTACK_WINDUP, State.ATTACK_STRIKE]

func _state_fear(delta: float):
	"""Состояние страха - убегает от игрока"""
	# Обновляем таймер
	fear_timer -= delta
	
	if fear_timer <= 0.0:
		exit_fear_state()
		return
	
	# Обновляем направление убегания
	if target:
		fear_direction = (global_position - target.global_position).normalized()
	
	# Убегаем с увеличенной скоростью (150% от обычной)
	var flee_speed = enemy_data.move_speed * 1.5 if enemy_data else 100.0
	velocity = velocity.move_toward(fear_direction * flee_speed, 2000.0 * delta)
	
	# Дополнительная визуализация (можно переопределить)
	_process_fear_visuals(delta)

func _process_fear_visuals(delta: float):
	"""Обновляет визуальные эффекты страха (переопределите при необходимости)"""
	# Легкое дрожание спрайта
	if sprite:
		var shake_amount = 2.0
		var shake = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		sprite.offset = shake

func _on_fear_entered():
	"""Вызывается при входе в состояние страха (переопределите при необходимости)"""
	# Изменяем цвет спрайта на фиолетовый
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.8, 0.6, 1.0, 1.0), 0.2)

func _on_fear_exited():
	"""Вызывается при выходе из состояния страха (переопределите при необходимости)"""
	# Возвращаем нормальный цвет
	if sprite:
		sprite.offset = Vector2.ZERO  # Убираем дрожание
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

# ============= COMBAT SYSTEM =============

func take_damage(amount: float, source_position: Vector2, knockback_direction: Vector2 = Vector2.ZERO):
	if is_invulnerable or state == State.DEAD or not enemy_data:
		return
	
	current_health -= amount
	health_changed.emit(current_health, enemy_data.max_health)
	
	_on_damage_taken(amount, source_position)
	
	# Применяем knockback с учётом сопротивления
	if knockback_direction != Vector2.ZERO:
		velocity += knockback_direction * enemy_data.knockback_resistance
	
	if current_health <= 0:
		_die()

func _on_damage_taken(amount: float, source_position: Vector2):
	_flash_sprite()

func _die():
	# Выходим из страха перед смертью
	if is_feared:
		is_feared = false
		fear_timer = 0.0
	
	state = State.DEAD
	died.emit()
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	_on_death()
	
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _on_death():
	if anim and anim.has_animation("death"):
		anim.play("death")

# ============= TARGET UTILITIES =============

func get_distance_to_target() -> float:
	if not target:
		return INF
	return global_position.distance_to(target.global_position)

func get_direction_to_target() -> Vector2:
	if not target:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()

func is_target_in_range(range_distance: float) -> bool:
	return get_distance_to_target() <= range_distance

func move_towards_target(delta: float, speed: float = 0.0):
	if speed == 0.0 and enemy_data:
		speed = enemy_data.move_speed
	
	var direction = get_direction_to_target()
	velocity = velocity.move_toward(direction * speed, 2000.0 * delta)

func stop_moving(delta: float):
	velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)

# ============= BEAT UTILITIES =============

func get_beat_progress() -> float:
	return current_beat - floor(current_beat)

func is_near_beat(threshold: float = 0.1) -> bool:
	var progress = get_beat_progress()
	return progress < threshold or progress > (1.0 - threshold)

func wait_for_next_beat() -> void:
	var current_beat_int = int(floor(current_beat))
	while int(floor(current_beat)) == current_beat_int:
		await get_tree().process_frame

# ============= VISUALS =============

func _update_visuals():
	if not sprite:
		return
	
	# В состоянии страха смотрим в сторону убегания
	if state == State.FEAR:
		sprite.flip_h = fear_direction.x > 0
		return
	
	# Иначе смотрим на цель
	if target:
		var to_target = target.global_position - global_position
		sprite.flip_h = to_target.x < 0

func _flash_sprite():
	if not sprite:
		return
	
	var original_modulate = sprite.modulate
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.15)

# ============= STATE MANAGEMENT =============

func change_state(new_state: State):
	if state == new_state:
		return
	
	var old_state = state
	state = new_state
	_on_state_changed(old_state, new_state)

func _on_state_changed(old_state: State, new_state: State):
	pass
