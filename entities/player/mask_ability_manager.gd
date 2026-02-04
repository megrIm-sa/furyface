class_name MaskAbilityManager
extends Node

signal mask_changed(mask: BaseMask)
signal ability_activated()
signal ability_deactivated()
signal mask_texture_changed(texture: Texture2D)

@export_group("Starting Mask")
@export var starting_mask_type: Enums.MaskType = Enums.MaskType.RAGE

@export_group("Ability Settings")
@export var min_ability_duration: float = 5.0

@export_group("Dependencies")
@export var combo_component: ComboComponent
@export var weapon_manager: WeaponManager  # Для передачи в RageMask
@export var visual_parent: Node2D  # Родитель для визуальных эффектов (обычно Player)

var mask_scenes: Dictionary = {
	Enums.MaskType.RAGE: preload("res://entities/player/masks/rage_mask.tscn"),
	Enums.MaskType.FEAR: preload("res://entities/player/masks/fear_mask.tscn")
}

var current_mask: BaseMask
var is_ability_active: bool = false
var ability_active_timer: float = 0.0

func _ready() -> void:
	if not combo_component:
		push_error("MaskAbilityManager: combo_component not assigned!")
		return
	
	# Подключаемся к сигналам комбо
	_connect_combo_signals()
	
	# Загружаем стартовую маску
	if starting_mask_type in mask_scenes:
		var mask = mask_scenes[starting_mask_type].instantiate() as BaseMask
		equip_mask(mask)
	else:
		push_error("MaskAbilityManager: Invalid starting_mask_type!")

func _process(delta: float) -> void:
	# Обновляем таймер активности способности
	if ability_active_timer > 0.0:
		ability_active_timer -= delta
		
		if ability_active_timer <= 0.0 and not combo_component.is_maxed():
			_deactivate_ability()
	
	# Обновляем текущую маску
	if current_mask and current_mask.is_active:
		current_mask.process_mask(delta)

func _connect_combo_signals() -> void:
	if not combo_component:
		return
	
	combo_component.combo_maxed.connect(_on_combo_maxed)
	combo_component.combo_below_max.connect(_on_combo_below_max)
	combo_component.combo_broken.connect(_on_combo_broken)

# ============= COMBO EVENTS =============

func _on_combo_maxed() -> void:
	if is_ability_active:
		ability_active_timer = min_ability_duration
		return
	
	_activate_ability()

func _on_combo_below_max() -> void:
	if is_ability_active and ability_active_timer <= 0.0:
		_deactivate_ability()

func _on_combo_broken() -> void:
	if is_ability_active:
		_deactivate_ability()

func _activate_ability() -> void:
	is_ability_active = true
	ability_active_timer = min_ability_duration
	
	ability_activated.emit()
	
	if current_mask:
		current_mask.on_combo_max_reached()

func _deactivate_ability() -> void:
	if not is_ability_active:
		return
	
	is_ability_active = false
	ability_active_timer = 0.0
	
	ability_deactivated.emit()
	
	if current_mask:
		current_mask.on_combo_lost()

# ============= МАСКИ =============

func switch_mask(mask_type: Enums.MaskType) -> void:
	if mask_type in mask_scenes:
		var mask_scene = mask_scenes[mask_type]
		equip_mask_scene(mask_scene)
	else:
		push_warning("MaskAbilityManager: No scene for mask type %s" % Enums.MaskType.keys()[mask_type])

func equip_mask(mask: BaseMask) -> void:
	"""Экипирует новую маску"""
	# Удаляем старую маску
	if current_mask:
		current_mask.deactivate()
		current_mask.queue_free()
	
	# Устанавливаем новую маску
	current_mask = mask
	add_child(current_mask)
	
	# Подключаем зависимости через @export
	_setup_mask_dependencies(current_mask)
	
	# Уведомляем об изменении текстуры маски
	if current_mask.mask_texture:
		mask_texture_changed.emit(current_mask.mask_texture)
	
	mask_changed.emit(current_mask)
	
	# Если комбо уже на максимуме, активируем
	if combo_component and combo_component.is_maxed():
		_activate_ability()

func equip_mask_scene(mask_scene: PackedScene) -> void:
	var mask = mask_scene.instantiate() as BaseMask
	if mask:
		equip_mask(mask)
	else:
		push_warning("MaskAbilityManager: Failed to instantiate mask scene!")

func _setup_mask_dependencies(mask: BaseMask) -> void:
	"""Настраивает зависимости маски"""
	# Устанавливаем visual_parent
	if visual_parent:
		mask.visual_parent = visual_parent
	
	# Для RageMask подключаем WeaponManager
	if mask is RageMask:
		var rage_mask = mask as RageMask
		rage_mask.weapon_manager = weapon_manager
	
	# Для FearMask ничего дополнительно не нужно

func get_current_mask_icon() -> Texture2D:
	if current_mask:
		return current_mask.mask_texture
	return null

# ============= WEAPON HIT CALLBACK =============

func on_weapon_hit_enemy(enemy: Node2D, damage: float, hit_type: Enums.HitType) -> void:
	"""Вызывается когда оружие попадает по врагу"""
	if current_mask:
		current_mask.on_weapon_hit_enemy(enemy, damage, hit_type)
