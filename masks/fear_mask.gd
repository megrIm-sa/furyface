# res://scripts/masks/fear_mask.gd
class_name FearMask
extends BaseMask

@export_group("Fear Ability")
@export var fear_duration: float = 3.0  # Длительность страха
@export var fear_chance: float = 1.0  # Шанс наложить страх (1.0 = 100%)
@export var fear_on_perfect_only: bool = false  # Страх только при PERFECT ударах

func _ready():
	mask_name = "Mask of Fear"
	mask_type = Enums.MaskType.FEAR
	description = "Weapon hits cause enemies to flee in terror"
	activation_color = Color(0.6, 0.2, 1.0, 1.0)  # Фиолетовый
	
	# Настройки визуального круга
	use_visual_circle = true
	circle_radius = 8.0
	circle_color = Color(0.6, 0.2, 1.0, 0.25)  # Фиолетовый полупрозрачный
	circle_outline_color = Color(0.8, 0.4, 1.0, 0.7)  # Светло-фиолетовый контур
	circle_outline_width = 3.5
	circle_pulse_speed = 1.8
	circle_pulse_min = 0.95
	circle_pulse_max = 1.05
	circle_pulse_alpha = true
	await get_tree().process_frame

	ability_manager.player.mask_sprite.modulate = activation_color
	

func _on_activate():
	_apply_visual_effects()
	

func _on_deactivate():
	_remove_visual_effects()

func on_weapon_hit_enemy(enemy: Node2D, _damage: float):
	"""Вызывается когда оружие попадает по врагу"""
	if not is_active:
		return
	
	# Проверяем шанс
	if randf() > fear_chance:
		return
	
	# Применяем страх
	if enemy.has_method("enter_fear_state"):
		enemy.enter_fear_state(fear_duration)
		print("[FearMask] Applied fear to %s for %.1fs" % [enemy.name, fear_duration])
	else:
		push_warning("[FearMask] Enemy %s doesn't support fear" % enemy.name)

func _apply_visual_effects():
	"""Визуальные эффекты активации"""
	if not ability_manager or not ability_manager.player:
		return
	
	#var mask_sprite = ability_manager.player.mask_sprite
	#if mask_sprite:
		#var target_color = activation_color
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
