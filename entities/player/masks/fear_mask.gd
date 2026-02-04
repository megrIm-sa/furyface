class_name FearMask
extends BaseMask

signal fear_applied(enemy: Node2D, duration: float)

@export_group("Fear Ability")
@export var fear_duration: float = 3.0
@export var fear_chance: float = 1.0  # 1.0 = 100%
@export var fear_on_perfect_only: bool = false

func _ready() -> void:
	mask_name = "Mask of Fear"
	mask_type = Enums.MaskType.FEAR
	description = "Weapon hits cause enemies to flee in terror"
	activation_color = Color(0.6, 0.2, 1.0, 1.0)
	
	# Настройки визуального круга
	circle_radius = 8.0
	circle_color = Color(0.6, 0.2, 1.0, 0.25)
	circle_outline_color = Color(0.8, 0.4, 1.0, 0.7)
	circle_outline_width = 3.5
	circle_pulse_speed = 1.8
	circle_pulse_min = 0.95
	circle_pulse_max = 1.05
	circle_pulse_alpha = true

func on_weapon_hit_enemy(enemy: Node2D, _damage: float, hit_type: Enums.HitType) -> void:
	"""Вызывается когда оружие попадает по врагу"""
	if not is_active:
		return
	
	# Проверяем условие perfect only
	if fear_on_perfect_only and hit_type != Enums.HitType.PERFECT:
		return
	
	# Проверяем шанс
	if randf() > fear_chance:
		return
	
	# Применяем страх
	if enemy.has_method("enter_fear_state"):
		enemy.enter_fear_state(fear_duration)
		fear_applied.emit(enemy, fear_duration)
	else:
		push_warning("[FearMask] Enemy %s doesn't support fear" % enemy.name)
