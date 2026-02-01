# res://scripts/masks/rage_mask.gd
class_name RageMask
extends BaseMask

@export_group("Rage Ability")
@export var damage_multiplier: float = 1.5
@export var visual_intensity: float = 1.0

var original_damage_modifiers: Dictionary = {}

func _ready():
	mask_name = "Mask of Rage"
	mask_type = Enums.MaskType.RAGE
	description = "Increases weapon damage when combo is maxed"
	activation_color = Color(1.0, 0.2, 0.2, 1.0)
	
	# Настройки визуального круга
	use_visual_circle = true
	circle_radius = 8.0
	circle_color = Color(1.0, 0.2, 0.2, 0.25)  # Красный полупрозрачный
	circle_outline_color = Color(1.0, 0.4, 0.2, 0.7)  # Оранжевый контур
	circle_outline_width = 4.0
	circle_pulse_speed = 2.5
	circle_pulse_min = 0.92
	circle_pulse_max = 1.08
	circle_pulse_alpha = true
	
	await get_tree().process_frame
	ability_manager.player.mask_sprite.modulate = activation_color
	


func _on_activate():
	_apply_damage_boost()
	_apply_visual_effects()

func _on_deactivate():
	_remove_damage_boost()
	_remove_visual_effects()

func _apply_damage_boost():
	"""Увеличивает урон всего оружия"""
	if not ability_manager or not ability_manager.player:
		return
	
	var weapon_manager = ability_manager.player.weapon_manager
	if not weapon_manager:
		return
	
	for weapon in weapon_manager.weapons.values():
		if weapon and weapon.weapon_data:
			var weapon_type = weapon.weapon_data.weapon_type
			if weapon_type not in original_damage_modifiers:
				original_damage_modifiers[weapon_type] = weapon.weapon_data.base_damage
			
			weapon.weapon_data.base_damage *= damage_multiplier
			print("[RageMask] Boosted %s damage: %.1f -> %.1f" % [
				weapon.weapon_data.weapon_name,
				original_damage_modifiers[weapon_type],
				weapon.weapon_data.base_damage
			])

func _remove_damage_boost():
	"""Восстанавливает оригинальный урон"""
	if not ability_manager or not ability_manager.player:
		return
	
	var weapon_manager = ability_manager.player.weapon_manager
	if not weapon_manager:
		return
	
	for weapon in weapon_manager.weapons.values():
		if weapon and weapon.weapon_data:
			var weapon_type = weapon.weapon_data.weapon_type
			if weapon_type in original_damage_modifiers:
				weapon.weapon_data.base_damage = original_damage_modifiers[weapon_type]
	
	original_damage_modifiers.clear()

func _apply_visual_effects():
	"""Визуальные эффекты активации"""
	if not ability_manager or not ability_manager.player:
		return
	
	#var mask_sprite = ability_manager.player.mask_sprite
	#if mask_sprite:
		#var target_color = activation_color
		#target_color.a = visual_intensity
		#
		#var tween = create_tween()
		#tween.tween_property(mask_sprite, "modulate", target_color, 0.3)

func _remove_visual_effects():
	"""Убирает визуальные эффекты"""
	if not ability_manager or not ability_manager.player:
		return
	
	#var mask_sprite = ability_manager.player.mask_sprite
	#if mask_sprite:
		#var tween = create_tween()
		#tween.tween_property(mask_sprite, "modulate", Color.WHITE, 0.3)
