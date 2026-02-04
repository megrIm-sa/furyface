class_name Weapon
extends Node2D

signal attack_performed(weapon: Weapon, hit_type: Enums.HitType, damage: float)
signal cooldown_ready()
signal enemy_hit(enemy: Node2D, damage: float, hit_type: Enums.HitType)

@export_group("Weapon Configuration")
@export var weapon_data: WeaponResource

var cooldown_timer: float = 0.0
var is_active: bool = false

var total_attacks: int = 0
var perfect_hits: int = 0

func _ready() -> void:
	if not weapon_data:
		push_error("Weapon %s: weapon_data not assigned!" % name)
		return
	
	# Убеждаемся что оружие не активно при создании
	is_active = false
	visible = false

func activate() -> void:
	"""Активирует оружие"""
	if is_active:
		return
	
	is_active = true
	visible = true
	_on_activated()

func deactivate() -> void:
	"""Деактивирует оружие"""
	if not is_active:
		return
	
	is_active = false
	visible = false
	_on_deactivated()

func can_attack() -> bool:
	"""Проверяет, может ли оружие атаковать"""
	return is_active and cooldown_timer <= 0.0

func attack(hit_type: Enums.HitType) -> void:
	"""Выполняет атаку"""
	if not can_attack() or not weapon_data:
		return
	
	total_attacks += 1
	if hit_type == Enums.HitType.PERFECT:
		perfect_hits += 1
	
	var damage_multiplier = _get_damage_multiplier(hit_type)
	var final_damage = weapon_data.base_damage * damage_multiplier
	
	_perform_attack(hit_type, final_damage)
	
	cooldown_timer = weapon_data.attack_cooldown
	attack_performed.emit(self, hit_type, final_damage)

func weapon_process(delta: float) -> void:
	"""Обрабатывает логику оружия каждый кадр"""
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			cooldown_ready.emit()
	
	_process_weapon_logic(delta)

func get_aim_direction() -> Vector2:
	"""Возвращает направление к курсору мыши"""
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	
	if direction.length() < 0.1:
		return Vector2.RIGHT
	
	return direction

# ============= ПЕРЕОПРЕДЕЛЯЕМЫЕ МЕТОДЫ =============

func _on_activated() -> void:
	"""Вызывается при активации оружия (переопределите в наследниках)"""
	pass

func _on_deactivated() -> void:
	"""Вызывается при деактивации оружия (переопределите в наследниках)"""
	pass

func _perform_attack(hit_type: Enums.HitType, damage: float) -> void:
	"""Выполняет атаку (переопределите в наследниках)"""
	pass

func _process_weapon_logic(delta: float) -> void:
	"""Обрабатывает специфичную логику оружия (переопределите при необходимости)"""
	pass

func on_missed_beat() -> void:
	"""Вызывается при промахе по биту (переопределите при необходимости)"""
	pass

# ============= HELPER METHODS =============

func _get_damage_multiplier(hit_type: Enums.HitType) -> float:
	"""Возвращает множитель урона в зависимости от типа попадания"""
	match hit_type:
		Enums.HitType.PERFECT:
			return 1.5
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			return 1.0
		_:
			return 0.5

func _notify_enemy_hit(enemy: Node2D, damage: float, hit_type: Enums.HitType) -> void:
	"""Уведомляет о попадании по врагу через сигнал"""
	enemy_hit.emit(enemy, damage, hit_type)

func get_stats() -> Dictionary:
	"""Возвращает статистику оружия"""
	return {
		"total_attacks": total_attacks,
		"perfect_hits": perfect_hits,
		"accuracy": (float(perfect_hits) / total_attacks * 100.0) if total_attacks > 0 else 0.0
	}
