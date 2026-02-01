# res://scripts/masks/base_mask.gd
class_name BaseMask
extends Node

signal mask_activated()
signal mask_deactivated()

@export_group("Mask Info")
@export var mask_name: String = "Unknown Mask"
@export var mask_type: Enums.MaskType = Enums.MaskType.RAGE
@export var description: String = ""

@export_group("Visual")
@export var mask_texture: Texture2D  # Спрайт маски на персонаже
@export var mask_icon: Texture2D  # Иконка для UI
@export var activation_color: Color = Color(1.0, 0.2, 0.2, 1.0)

@export_group("Visual Circle")
@export var use_visual_circle: bool = true
@export var circle_radius: float = 8.0
@export var circle_color: Color = Color(1.0, 0.2, 0.2, 0.3)
@export var circle_outline_color: Color = Color(1.0, 0.4, 0.4, 0.6)
@export var circle_outline_width: float = 3.0
@export var circle_pulse_speed: float = 2.0
@export var circle_pulse_min: float = 0.95
@export var circle_pulse_max: float = 1.05
@export var circle_pulse_alpha: bool = true

var ability_manager: MaskAbilityManager
var is_active: bool = false
var mask_visual: MaskVisual = null

func activate():
	"""Активирует способность маски"""
	if is_active:
		return
	
	is_active = true
	_create_visual_circle()
	_on_activate()
	mask_activated.emit()
	print("[%s] Mask activated!" % mask_name)

func deactivate():
	"""Деактивирует способность маски"""
	if not is_active:
		return
	
	is_active = false
	_remove_visual_circle()
	_on_deactivate()
	mask_deactivated.emit()
	print("[%s] Mask deactivated!" % mask_name)

func _create_visual_circle():
	"""Создает визуальный круг вокруг игрока"""
	if not use_visual_circle or not ability_manager or not ability_manager.player:
		return
	
	mask_visual = MaskVisual.new()
	mask_visual.radius = circle_radius
	mask_visual.color = circle_color
	mask_visual.outline_color = circle_outline_color
	mask_visual.outline_width = circle_outline_width
	mask_visual.pulse_speed = circle_pulse_speed
	mask_visual.pulse_min_scale = circle_pulse_min
	mask_visual.pulse_max_scale = circle_pulse_max
	mask_visual.pulse_alpha = circle_pulse_alpha
	mask_visual.z_index = 0
	
	ability_manager.player.add_child(mask_visual)
	print("[%s] Visual circle created" % mask_name)

func _remove_visual_circle():
	"""Удаляет визуальный круг"""
	if mask_visual:
		mask_visual.queue_free()
		mask_visual = null

# Переопределяемые методы
func _on_activate():
	"""Вызывается при активации маски"""
	pass

func _on_deactivate():
	"""Вызывается при деактивации маски"""
	pass

func on_combo_max_reached():
	"""Вызывается когда комбо достигает максимума"""
	activate()

func on_combo_lost():
	"""Вызывается когда комбо падает ниже максимума"""
	deactivate()

func process_mask(delta: float):
	"""Вызывается каждый кадр если маска активна"""
	pass

func on_weapon_hit_enemy(enemy: Node2D, damage: float):
	"""Вызывается когда оружие попадает по врагу (переопределите при необходимости)"""
	pass
