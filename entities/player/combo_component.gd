class_name ComboComponent
extends Node

signal combo_changed(current: float, maximum: float)
signal combo_added(amount: float, new_total: float)
signal combo_removed(amount: float, new_total: float)
signal combo_maxed()
signal combo_below_max()
signal combo_broken()

@export_group("Combo Settings")
@export var max_combo: float = 100.0
@export var start_combo: float = 0.0
@export var combo_decay_rate: float = 10.0
@export var decay_enabled: bool = true

@export_group("Gain/Loss Amounts")
@export var perfect_gain: float = 15.0
@export var good_gain: float = 8.0
@export var miss_loss: float = 25.0

var current_combo: float = 0.0
var is_at_max: bool = false

func _ready() -> void:
	current_combo = start_combo
	
	await get_tree().process_frame
	combo_changed.emit(current_combo, max_combo)

func _process(delta: float) -> void:
	if decay_enabled:
		_apply_decay(delta)

## Добавляет комбо
func add_combo(amount: float) -> void:
	if amount <= 0.0:
		return
	
	var old_combo = current_combo
	current_combo = min(max_combo, current_combo + amount)
	
	combo_added.emit(amount, current_combo)
	
	if old_combo != current_combo:
		combo_changed.emit(current_combo, max_combo)
		_check_max_threshold()

## Убирает комбо
func remove_combo(amount: float) -> void:
	if amount <= 0.0:
		return
	
	var old_combo = current_combo
	current_combo = max(0.0, current_combo - amount)
	
	combo_removed.emit(amount, current_combo)
	
	if old_combo != current_combo:
		combo_changed.emit(current_combo, max_combo)
		_check_max_threshold()

## Устанавливает комбо напрямую
func set_combo(value: float) -> void:
	var old_combo = current_combo
	current_combo = clamp(value, 0.0, max_combo)
	
	if old_combo != current_combo:
		combo_changed.emit(current_combo, max_combo)
		_check_max_threshold()

## Обнуляет комбо
func reset_combo() -> void:
	if current_combo > 0.0:
		current_combo = 0.0
		combo_changed.emit(current_combo, max_combo)
		combo_broken.emit()
		_check_max_threshold()

## Максимизирует комбо
func max_out_combo() -> void:
	set_combo(max_combo)

## Проверяет, достигнуто ли максимальное комбо
func is_maxed() -> bool:
	return current_combo >= max_combo

## Возвращает процент заполнения комбо (0.0 - 1.0)
func get_combo_percent() -> float:
	return current_combo / max_combo if max_combo > 0.0 else 0.0

## Возвращает оставшееся комбо до максимума
func get_combo_remaining() -> float:
	return max(0.0, max_combo - current_combo)

## Обрабатывает попадание на основе HitType
func process_hit(hit_type: Enums.HitType) -> void:
	match hit_type:
		Enums.HitType.PERFECT:
			add_combo(perfect_gain)
		
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			add_combo(good_gain)
		
		Enums.HitType.MISS_EARLY, Enums.HitType.MISS_LATE:
			remove_combo(miss_loss)

## Включает/выключает decay
func set_decay_enabled(enabled: bool) -> void:
	decay_enabled = enabled

## Изменяет скорость decay
func set_decay_rate(rate: float) -> void:
	combo_decay_rate = max(0.0, rate)

func _apply_decay(delta: float) -> void:
	if current_combo <= 0.0 or combo_decay_rate <= 0.0:
		return
	
	var old_combo = current_combo
	current_combo = max(0.0, current_combo - combo_decay_rate * delta)
	
	if old_combo != current_combo:
		combo_changed.emit(current_combo, max_combo)
		_check_max_threshold()

func _check_max_threshold() -> void:
	var now_at_max = is_maxed()
	
	if now_at_max and not is_at_max:
		# Достигли максимума
		is_at_max = true
		combo_maxed.emit()
	
	elif not now_at_max and is_at_max:
		# Упали ниже максимума
		is_at_max = false
		combo_below_max.emit()
