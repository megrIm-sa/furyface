class_name DashComponent
extends Node

signal dash_started(hit_type: Enums.HitType)
signal dash_finished()
signal dash_cooldown_changed(current: float, maximum: float)
signal dash_charges_changed(current: int, maximum: int)
signal perfect_dash()  # Когда сделан perfect dash
signal missed_dash()   # Когда промах

@export_group("Dash Configuration")
@export var base_dash_speed: float = 500.0
@export var base_dash_duration: float = 0.2
@export var base_dash_cooldown: float = 1.0
@export var base_dash_distance: float = 100.0

@export_group("Timing Modifiers")
@export var perfect_speed_multiplier: float = 1.5
@export var perfect_duration_multiplier: float = 1.2
@export var perfect_cooldown_reduction: float = 0.3  # -30% к кулдауну

@export var good_speed_multiplier: float = 1.0
@export var good_duration_multiplier: float = 1.0
@export var good_cooldown_reduction: float = 0.0

@export var miss_speed_multiplier: float = 0.6
@export var miss_duration_multiplier: float = 0.8
@export var miss_cooldown_penalty: float = 0.5  # +50% к кулдауну

@export_group("Advanced")
@export var max_dash_charges: int = 1
@export var invincible_during_dash: bool = true
@export var cancel_dash_on_miss: bool = false  # Отменять ли dash при промахе

@export_group("Dependencies")
@export var body: CharacterBody2D
@export var health_component: HealthComponent

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

# Текущие параметры dash (меняются в зависимости от hit_type)
var current_dash_speed: float = 500.0
var current_dash_duration: float = 0.2

var current_charges: int = 1
var was_invincible_before_dash: bool = false
var last_hit_type: Enums.HitType = Enums.HitType.MISS_LATE

func _ready() -> void:
	current_charges = max_dash_charges
	
	# Инициализируем UI
	dash_cooldown_changed.emit(0.0, base_dash_cooldown)
	if max_dash_charges > 1:
		dash_charges_changed.emit(current_charges, max_dash_charges)

func _physics_process(delta: float) -> void:
	if is_dashing:
		_process_dash(delta)
	
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		
		# Уведомляем UI об изменении
		dash_cooldown_changed.emit(dash_cooldown_timer, _get_modified_cooldown(last_hit_type))
		
		if dash_cooldown_timer <= 0.0:
			_on_cooldown_finished()

func try_dash(hit_type: Enums.HitType, input_direction: Vector2, facing_direction: Vector2) -> bool:
	"""Пытается выполнить dash с учетом тайминга нажатия"""
	if not can_dash():
		return false
	
	# Определяем направление dash
	var dash_dir = _determine_dash_direction(input_direction, facing_direction)
	
	if dash_dir.length() < 0.1:
		return false
	
	# Проверяем miss - возможно отменяем dash
	if cancel_dash_on_miss and hit_type in [Enums.HitType.MISS_LATE, Enums.HitType.MISS_EARLY]:
		missed_dash.emit()
		return false
	
	_start_dash(dash_dir.normalized(), hit_type)
	return true

func can_dash() -> bool:
	"""Проверяет, можно ли сделать dash"""
	return not is_dashing and dash_cooldown_timer <= 0.0 and current_charges > 0

func is_on_cooldown() -> bool:
	"""Проверяет, на кулдауне ли dash"""
	return dash_cooldown_timer > 0.0

func get_cooldown_remaining() -> float:
	"""Возвращает оставшееся время кулдауна"""
	return dash_cooldown_timer

func get_cooldown_percent() -> float:
	"""Возвращает процент завершения кулдауна (0.0 - 1.0)"""
	var max_cooldown = _get_modified_cooldown(last_hit_type)
	if max_cooldown <= 0.0:
		return 1.0
	
	return 1.0 - (dash_cooldown_timer / max_cooldown)

func _determine_dash_direction(input_direction: Vector2, facing_direction: Vector2) -> Vector2:
	"""Определяет направление dash на основе ввода и направления взгляда"""
	# Если есть ввод, используем его
	if input_direction.length() > 0.1:
		return input_direction
	
	# Иначе используем направление взгляда
	return facing_direction

func _start_dash(direction: Vector2, hit_type: Enums.HitType) -> void:
	"""Начинает dash с модификаторами на основе hit_type"""
	last_hit_type = hit_type
	
	# Вычисляем модифицированные параметры
	var speed_mult = _get_speed_multiplier(hit_type)
	var duration_mult = _get_duration_multiplier(hit_type)
	
	current_dash_speed = base_dash_speed * speed_mult
	current_dash_duration = base_dash_duration * duration_mult
	
	is_dashing = true
	dash_timer = current_dash_duration
	dash_direction = direction
	dash_cooldown_timer = _get_modified_cooldown(hit_type)
	
	# Используем заряд
	current_charges -= 1
	if max_dash_charges > 1:
		dash_charges_changed.emit(current_charges, max_dash_charges)
	
	# Устанавливаем неуязвимость
	if invincible_during_dash and health_component:
		was_invincible_before_dash = health_component.is_invincible
		health_component.set_invincible(true)
	
	# Уведомляем UI и другие системы
	dash_cooldown_changed.emit(dash_cooldown_timer, _get_modified_cooldown(hit_type))
	dash_started.emit(hit_type)
	
	# Специальные события для perfect
	if hit_type == Enums.HitType.PERFECT:
		perfect_dash.emit()

func _process_dash(delta: float) -> void:
	"""Обрабатывает движение во время dash"""
	if not body:
		return
	
	dash_timer -= delta
	
	if dash_timer <= 0.0:
		_finish_dash()
		return
	
	# Применяем движение с текущей скоростью
	body.velocity = dash_direction * current_dash_speed

func _finish_dash() -> void:
	"""Завершает dash"""
	is_dashing = false
	dash_timer = 0.0
	
	# Восстанавливаем неуязвимость
	if invincible_during_dash and health_component:
		health_component.set_invincible(was_invincible_before_dash)
	
	dash_finished.emit()

func _on_cooldown_finished() -> void:
	"""Вызывается когда кулдаун завершен"""
	dash_cooldown_timer = 0.0
	
	# Восстанавливаем заряд
	current_charges = max_dash_charges
	if max_dash_charges > 1:
		dash_charges_changed.emit(current_charges, max_dash_charges)
	
	# Уведомляем UI
	dash_cooldown_changed.emit(0.0, base_dash_cooldown)

# ============= TIMING MODIFIERS =============

func _get_speed_multiplier(hit_type: Enums.HitType) -> float:
	"""Возвращает множитель скорости для типа попадания"""
	match hit_type:
		Enums.HitType.PERFECT:
			return perfect_speed_multiplier
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			return good_speed_multiplier
		_:
			return miss_speed_multiplier

func _get_duration_multiplier(hit_type: Enums.HitType) -> float:
	"""Возвращает множитель длительности для типа попадания"""
	match hit_type:
		Enums.HitType.PERFECT:
			return perfect_duration_multiplier
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			return good_duration_multiplier
		_:
			return miss_duration_multiplier

func _get_modified_cooldown(hit_type: Enums.HitType) -> float:
	"""Возвращает модифицированный кулдаун для типа попадания"""
	var cooldown = base_dash_cooldown
	
	match hit_type:
		Enums.HitType.PERFECT:
			cooldown *= (1.0 - perfect_cooldown_reduction)
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			cooldown *= (1.0 - good_cooldown_reduction)
		_:
			cooldown *= (1.0 + miss_cooldown_penalty)
	
	return cooldown

# ============= UTILITY METHODS =============

## Сбрасывает кулдаун (для пауэрапов)
func reset_cooldown() -> void:
	dash_cooldown_timer = 0.0
	current_charges = max_dash_charges
	dash_cooldown_changed.emit(0.0, base_dash_cooldown)
	if max_dash_charges > 1:
		dash_charges_changed.emit(current_charges, max_dash_charges)

## Добавляет дополнительный заряд (для апгрейдов)
func add_charge() -> void:
	max_dash_charges += 1
	current_charges += 1
	dash_charges_changed.emit(current_charges, max_dash_charges)

## Возвращает информацию о текущем dash
func get_dash_info() -> Dictionary:
	return {
		"is_dashing": is_dashing,
		"dash_timer": dash_timer,
		"cooldown_timer": dash_cooldown_timer,
		"current_charges": current_charges,
		"max_charges": max_dash_charges,
		"current_speed": current_dash_speed,
		"current_duration": current_dash_duration,
		"last_hit_type": last_hit_type
	}

## Улучшает параметры dash (для системы апгрейдов)
func upgrade_dash_speed(multiplier: float) -> void:
	base_dash_speed *= multiplier

func upgrade_dash_duration(multiplier: float) -> void:
	base_dash_duration *= multiplier

func upgrade_dash_cooldown(reduction: float) -> void:
	base_dash_cooldown *= (1.0 - reduction)
