class_name DashComponent
extends Node

signal dash_started(direction: Vector2, hit_type: Enums.HitType)
signal dash_finished()
signal dash_cooldown_changed(current: float, maximum: float)
signal perfect_dash()
signal missed_dash()

@export_group("Dash Configuration")
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0

@export_group("Timing Modifiers")
@export var perfect_speed_mult: float = 1.5
@export var perfect_duration_mult: float = 1.2
@export var perfect_cooldown_mult: float = 0.7

@export var good_speed_mult: float = 1.0
@export var good_duration_mult: float = 1.0
@export var good_cooldown_mult: float = 1.0

@export var miss_speed_mult: float = 0.6
@export var miss_duration_mult: float = 0.8
@export var miss_cooldown_mult: float = 1.5

@export_group("Advanced")
@export var invincible_during_dash: bool = true
@export var cancel_dash_on_miss: bool = false

@export_group("Dependencies")
@export var body: CharacterBody2D
@export var health_component: HealthComponent

var is_dashing: bool = false
var cooldown_timer: float = 0.0

var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var current_speed: float = 0.0

var was_invulnerable_before_dash: bool = false
var last_hit_type: Enums.HitType = Enums.HitType.GOOD_EARLY

func _ready() -> void:
	# Emit после создания для UI
	await get_tree().process_frame
	dash_cooldown_changed.emit(0.0, dash_cooldown)

func _physics_process(delta: float) -> void:
	if is_dashing:
		_process_dash(delta)
	
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		dash_cooldown_changed.emit(cooldown_timer, _get_modified_cooldown(last_hit_type))
		
		if cooldown_timer <= 0.0:
			cooldown_timer = 0.0
			dash_cooldown_changed.emit(0.0, dash_cooldown)

## Пытается выполнить dash. Возвращает true если успешно.
func try_dash(hit_type: Enums.HitType, input_direction: Vector2, facing_direction: Vector2) -> bool:
	if not can_dash():
		return false
	
	# Определяем направление dash
	var dash_dir = input_direction if input_direction.length() > 0.1 else facing_direction
	
	if dash_dir.length() < 0.1:
		return false
	
	# Отменяем dash при промахе если включено
	if cancel_dash_on_miss and _is_miss(hit_type):
		missed_dash.emit()
		return false
	
	_start_dash(dash_dir.normalized(), hit_type)
	return true

## Проверяет, можно ли сделать dash
func can_dash() -> bool:
	return not is_dashing and cooldown_timer <= 0.0

## Возвращает процент завершения кулдауна (0.0 - 1.0)
func get_cooldown_percent() -> float:
	var max_cooldown = _get_modified_cooldown(last_hit_type)
	return 1.0 - (cooldown_timer / max_cooldown) if max_cooldown > 0.0 else 1.0

## Возвращает оставшееся время кулдауна
func get_cooldown_remaining() -> float:
	return cooldown_timer

## Сбрасывает кулдаун (для пауэрапов)
func reset_cooldown() -> void:
	cooldown_timer = 0.0
	dash_cooldown_changed.emit(0.0, dash_cooldown)

func _start_dash(direction: Vector2, hit_type: Enums.HitType) -> void:
	"""Начинает dash с модификаторами"""
	last_hit_type = hit_type
	
	# Вычисляем параметры dash
	var speed_mult = _get_speed_multiplier(hit_type)
	var duration_mult = _get_duration_multiplier(hit_type)
	
	current_speed = dash_speed * speed_mult
	dash_timer = dash_duration * duration_mult
	dash_direction = direction
	
	is_dashing = true
	cooldown_timer = _get_modified_cooldown(hit_type)
	
	# Включаем неуязвимость
	if invincible_during_dash and health_component:
		was_invulnerable_before_dash = health_component.is_invulnerable
		health_component.set_invulnerable()
	
	dash_cooldown_changed.emit(cooldown_timer, _get_modified_cooldown(hit_type))
	dash_started.emit(direction, hit_type)
	
	if hit_type == Enums.HitType.PERFECT:
		perfect_dash.emit()

func _process_dash(delta: float) -> void:
	"""Обрабатывает движение во время dash"""
	if not body:
		_finish_dash()
		return
	
	dash_timer -= delta
	
	if dash_timer <= 0.0:
		_finish_dash()
		return
	
	# Применяем скорость dash
	body.velocity = dash_direction * current_speed

func _finish_dash() -> void:
	"""Завершает dash"""
	is_dashing = false
	dash_timer = 0.0
	
	# Восстанавливаем неуязвимость
	if invincible_during_dash and health_component:
		if not was_invulnerable_before_dash:
			health_component.remove_invulnerability()
	
	dash_finished.emit()

func _get_speed_multiplier(hit_type: Enums.HitType) -> float:
	"""Возвращает множитель скорости"""
	match hit_type:
		Enums.HitType.PERFECT:
			return perfect_speed_mult
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			return good_speed_mult
		_:
			return miss_speed_mult

func _get_duration_multiplier(hit_type: Enums.HitType) -> float:
	"""Возвращает множитель длительности"""
	match hit_type:
		Enums.HitType.PERFECT:
			return perfect_duration_mult
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			return good_duration_mult
		_:
			return miss_duration_mult

func _get_modified_cooldown(hit_type: Enums.HitType) -> float:
	"""Возвращает модифицированный кулдаун"""
	match hit_type:
		Enums.HitType.PERFECT:
			return dash_cooldown * perfect_cooldown_mult
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			return dash_cooldown * good_cooldown_mult
		_:
			return dash_cooldown * miss_cooldown_mult

func _is_miss(hit_type: Enums.HitType) -> bool:
	"""Проверяет, является ли тип попадания промахом"""
	return hit_type in [Enums.HitType.MISS_EARLY, Enums.HitType.MISS_LATE]
