class_name MeleeEnemy
extends Enemy

@onready var attack: MeleeAttackComponent = $MeleeAttackComponent
@onready var fear: FearComponent = $FearComponent

enum State { IDLE, CHASE, ATTACKING, FLEEING }
var state: State = State.IDLE

func _on_ready() -> void:
	# Настраиваем атаку
	if attack and enemy_data:
		attack.attack_range = enemy_data.attack_range
		attack.damage = enemy_data.damage
		attack.windup_beats = enemy_data.windup_beats
	
	# Подключаем сигналы атаки
	if attack:
		attack.attack_started.connect(_on_attack_started)
		attack.attack_executed.connect(_on_attack_executed)
		attack.windup_beat.connect(_on_windup_beat)
	
	# Подключаем сигналы страха
	if fear:
		fear.fear_entered.connect(_on_fear_entered)
		fear.fear_exited.connect(_on_fear_exited)

func _process_state(delta: float) -> void:
	# Страх имеет приоритет
	if fear and fear.is_in_fear():
		_state_fleeing(delta)
		return
	
	match state:
		State.IDLE:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACKING:
			_state_attacking(delta)

func _state_idle(delta: float) -> void:
	"""Состояние ожидания"""
	movement.stop_movement(self, delta)
	
	if targeting.has_target() and targeting.is_target_in_detection_range():
		state = State.CHASE

func _state_chase(delta: float) -> void:
	"""Состояние преследования"""
	if not targeting.has_target():
		state = State.IDLE
		return
	
	# Проверяем дистанцию
	if not targeting.is_target_in_detection_range():
		state = State.IDLE
		return
	
	# Если в радиусе атаки, останавливаемся
	if targeting.is_target_in_attack_range():
		movement.stop_movement(self, delta)
	else:
		# Двигаемся к цели
		var direction = targeting.get_direction_to_target()
		movement.apply_movement(self, direction, delta)

func _state_attacking(delta: float) -> void:
	"""Состояние атаки"""
	movement.stop_movement(self, delta)


func _state_fleeing(delta: float) -> void:
	"""Состояние страха (движение управляется FearComponent)"""
	pass

func _on_beat(beat: int) -> void:
	"""Обрабатывает бит"""
	match state:
		State.CHASE:
			# Пытаемся атаковать если в радиусе
			if targeting.is_target_in_attack_range() and attack and attack.can_attack():
				attack.try_start_attack()
				state = State.ATTACKING
		
		State.ATTACKING:
			# Передаем бит компоненту атаки
			if attack:
				attack.process_beat(beat)

func _on_attack_started() -> void:
	"""Вызывается при начале атаки"""
	if anim_controller:
		anim_controller.set_animation_position("attack", 0.0)

func _on_windup_beat(beats_passed: int, total_beats: int) -> void:
	"""Вызывается на каждом бите замаха"""
	# Синхронизируем анимацию с битами
	if anim_controller and anim_controller.anim_player:
		var anim_time = beats_passed * 0.1  # 0.1 секунды на бит
		anim_controller.set_animation_position("attack", anim_time)

func _on_attack_executed() -> void:
	"""Вызывается при выполнении удара"""
	# Продолжаем анимацию с момента удара
	if anim_controller:
		anim_controller.resume_animation_from("attack", 0.4)
	
	# ИСПРАВЛЕНО: завершаем атаку сразу без ожидания
	if attack:
		attack.finish_attack()
	
	# Небольшая задержка перед возвратом в chase
	await get_tree().create_timer(0.2).timeout
	
	# Возвращаемся к chase
	state = State.CHASE

func _on_fear_entered(_duration: float) -> void:
	"""Вызывается при входе в страх"""
	# Отменяем атаку если была
	if attack and attack.is_attacking:
		attack.cancel_attack()
	
	state = State.CHASE  # После страха вернемся в chase

func _on_fear_exited() -> void:
	"""Вызывается при выходе из страха"""
	# Возвращаемся к нормальному поведению
	if targeting.has_target():
		state = State.CHASE
	else:
		state = State.IDLE

func _on_state_changed(old_state: String, new_state: String) -> void:
	"""Обрабатывает смену состояния"""
	super._on_state_changed(old_state, new_state)
	
	# При смерти отменяем все эффекты
	if new_state == "dead":
		if attack:
			attack.cancel_attack()
		if fear:
			fear.exit_fear()
