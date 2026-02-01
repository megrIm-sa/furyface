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

var ability_manager: MaskAbilityManager
var is_active: bool = false

func activate():
	"""Активирует способность маски"""
	if is_active:
		return
	
	is_active = true
	_on_activate()
	mask_activated.emit()
	print("[%s] Mask activated!" % mask_name)

func deactivate():
	"""Деактивирует способность маски"""
	if not is_active:
		return
	
	is_active = false
	_on_deactivate()
	mask_deactivated.emit()
	print("[%s] Mask deactivated!" % mask_name)

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
