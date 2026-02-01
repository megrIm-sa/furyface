# res://scripts/masks/mask_ability_manager.gd
class_name MaskAbilityManager
extends Node

signal combo_changed(current: float, maximum: float)
signal combo_max_reached()
signal combo_lost()
signal mask_changed(mask: BaseMask)
signal ability_activated()
signal ability_deactivated()

@export var max_combo: float = 100.0
@export var combo_decay_rate: float = 10.0
@export var perfect_hit_combo_gain: float = 15.0
@export var good_hit_combo_gain: float = 8.0
@export var miss_combo_loss: float = 25.0
@export var min_ability_duration: float = 5.0  # Минимальное время действия способности


var mask_scenes: Dictionary = {
	Enums.MaskType.RAGE: preload("res://masks/rage_mask.tscn"),
	Enums.MaskType.FEAR: preload("res://masks/fear_mask.tscn")
}

var player: Player
var current_combo: float = 0.0
var current_mask: BaseMask
var was_at_max: bool = false
var ability_active_timer: float = 0.0  # Таймер для минимального времени

func _ready():
	player = get_parent() as Player
	assert(player != null, "MaskAbilityManager must be child of Player")
	
	# Загружаем стартовую маску
	var mask = mask_scenes[GlobalSettings.mask].instantiate() as BaseMask
	equip_mask(mask)

func _process(delta):
	_decay_combo(delta)
	
	# Обновляем таймер активности способности
	if ability_active_timer > 0.0:
		ability_active_timer -= delta
	
	if current_mask and current_mask.is_active:
		current_mask.process_mask(delta)

func _decay_combo(delta: float):
	"""Постепенно уменьшает комбо"""
	if current_combo <= 0.0:
		return
	
	var old_combo = current_combo
	current_combo = max(0.0, current_combo - combo_decay_rate * delta)
	
	if old_combo != current_combo:
		combo_changed.emit(current_combo, max_combo)
		_check_combo_thresholds()

func add_combo(amount: float):
	"""Добавляет комбо"""
	var old_combo = current_combo
	current_combo = min(max_combo, current_combo + amount)
	
	if old_combo != current_combo:
		combo_changed.emit(current_combo, max_combo)
		_check_combo_thresholds()
	
	print("[MaskAbility] Combo: %.1f / %.1f (+%.1f)" % [current_combo, max_combo, amount])

func remove_combo(amount: float):
	"""Убирает комбо"""
	var old_combo = current_combo
	current_combo = max(0.0, current_combo - amount)
	
	if old_combo != current_combo:
		combo_changed.emit(current_combo, max_combo)
		_check_combo_thresholds()
	
	print("[MaskAbility] Combo: %.1f / %.1f (-%.1f)" % [current_combo, max_combo, amount])


func switch_mask(mask_type: Enums.MaskType):
	"""Переключает маску на указанный тип"""
	if mask_type in mask_scenes:
		var mask_scene = mask_scenes[mask_type]
		equip_mask_scene(mask_scene)
	else:
		push_warning("MaskAbilityManager: No scene for mask type %s" % Enums.MaskType.keys()[mask_type])


func _check_combo_thresholds():
	"""Проверяет достижение максимального комбо"""
	var is_at_max = is_combo_maxed()
	
	if is_at_max and not was_at_max:
		# Достигли максимума
		was_at_max = true
		ability_active_timer = min_ability_duration  # Запускаем таймер
		combo_max_reached.emit()
		if current_mask:
			current_mask.on_combo_max_reached()
		ability_activated.emit()
	
	elif not is_at_max and was_at_max:
		# Комбо упало ниже максимума
		# Проверяем, прошло ли минимальное время
		if ability_active_timer <= 0.0:
			# Минимальное время прошло, деактивируем
			was_at_max = false
			combo_lost.emit()
			if current_mask:
				current_mask.on_combo_lost()
			ability_deactivated.emit()
		else:
			# Минимальное время еще не прошло, держим активацию
			print("[MaskAbility] Ability still active for %.1fs" % ability_active_timer)

func is_combo_maxed() -> bool:
	return current_combo >= max_combo

func is_ability_active() -> bool:
	return was_at_max

func get_combo_percent() -> float:
	return current_combo / max_combo if max_combo > 0.0 else 0.0

# ============= МАСКИ =============

func equip_mask(mask: BaseMask):
	"""Экипирует новую маску"""
	# Удаляем старую маску
	if current_mask:
		current_mask.deactivate()
		current_mask.queue_free()
	
	# Устанавливаем новую маску
	current_mask = mask
	current_mask.ability_manager = self
	add_child(current_mask)
	
	# Обновляем спрайт маски на игроке
	if player.mask_sprite and current_mask.mask_texture:
		player.mask_sprite.texture = current_mask.mask_texture
	
	mask_changed.emit(current_mask)
	print("[MaskAbility] Equipped mask: %s" % current_mask.mask_name)
	
	# Если уже на максимуме, активируем
	if is_combo_maxed():
		current_mask.on_combo_max_reached()

func equip_mask_scene(mask_scene: PackedScene):
	"""Экипирует маску из сцены"""
	var mask = mask_scene.instantiate() as BaseMask
	if mask:
		equip_mask(mask)
	else:
		push_warning("MaskAbilityManager: Failed to instantiate mask scene!")

func get_current_mask_icon() -> Texture2D:
	"""Возвращает иконку текущей маски"""
	if current_mask:
		return current_mask.mask_texture
	return null

# ============= ИНТЕГРАЦИЯ С БОЕВОЙ СИСТЕМОЙ =============

func on_weapon_hit(hit_type: Enums.HitType, damage_dealt: float):
	"""Вызывается когда игрок наносит урон"""
	match hit_type:
		Enums.HitType.PERFECT:
			add_combo(perfect_hit_combo_gain)
		
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			add_combo(good_hit_combo_gain)
		
		Enums.HitType.MISS_EARLY, Enums.HitType.MISS_LATE:
			remove_combo(miss_combo_loss)
