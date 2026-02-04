class_name RageMask
extends BaseMask

signal damage_boost_applied(multiplier: float)
signal damage_boost_removed()

@export_group("Rage Ability")
@export var damage_multiplier: float = 1.5

@export_group("Dependencies")
@export var weapon_manager: WeaponManager  # Прямая ссылка на WeaponManager

var original_damage_modifiers: Dictionary = {}

func _ready() -> void:
	mask_name = "Mask of Rage"
	mask_type = Enums.MaskType.RAGE
	description = "Increases weapon damage by %.0f%% when combo is maxed" % ((damage_multiplier - 1.0) * 100)
	activation_color = Color(1.0, 0.2, 0.2, 1.0)
	
	# Настройки визуального круга
	circle_radius = 8.0
	circle_color = Color(1.0, 0.2, 0.2, 0.25)
	circle_outline_color = Color(1.0, 0.4, 0.2, 0.7)
	circle_outline_width = 4.0
	circle_pulse_speed = 2.5
	circle_pulse_min = 0.92
	circle_pulse_max = 1.08
	circle_pulse_alpha = true

func _on_activate() -> void:
	_apply_damage_boost()

func _on_deactivate() -> void:
	_remove_damage_boost()

func _apply_damage_boost() -> void:
	"""Увеличивает урон всего оружия"""
	if not weapon_manager:
		push_warning("[RageMask] weapon_manager not assigned!")
		return
	
	for weapon in weapon_manager.weapons.values():
		if weapon and weapon.weapon_data:
			var weapon_type = weapon.weapon_data.weapon_type
			if weapon_type not in original_damage_modifiers:
				original_damage_modifiers[weapon_type] = weapon.weapon_data.base_damage
			
			weapon.weapon_data.base_damage *= damage_multiplier
	
	damage_boost_applied.emit(damage_multiplier)

func _remove_damage_boost() -> void:
	"""Восстанавливает оригинальный урон"""
	if not weapon_manager:
		return
	
	for weapon in weapon_manager.weapons.values():
		if weapon and weapon.weapon_data:
			var weapon_type = weapon.weapon_data.weapon_type
			if weapon_type in original_damage_modifiers:
				weapon.weapon_data.base_damage = original_damage_modifiers[weapon_type]
	
	original_damage_modifiers.clear()
	damage_boost_removed.emit()
