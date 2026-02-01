class_name Weapon
extends Node2D

signal attack_performed(hit_type: Enums.HitType)
signal cooldown_ready()

@export var weapon_data: WeaponResource  # Теперь можно использовать @export

var weapon_manager: WeaponManager
var cooldown_timer: float = 0.0
var is_active: bool = false

var upgrade_branches: Array[UpgradeBranch] = []
var total_attacks: int = 0
var perfect_hits: int = 0

func _ready():
	if not weapon_data:
		push_warning("Weapon %s: weapon_data not assigned!" % name)
		return
	
	_initialize_upgrade_branches()
	
	# Убеждаемся что оружие не активно при создании
	is_active = false
	visible = false
	set_physics_process(false)
	
	print("Weapon initialized: ", weapon_data.weapon_name, " - Active: ", is_active, " - Visible: ", visible)

func _initialize_upgrade_branches():
	var branch_1 = UpgradeBranch.new(weapon_data.branch_1_name, weapon_data.max_upgrade_level)
	var branch_2 = UpgradeBranch.new(weapon_data.branch_2_name, weapon_data.max_upgrade_level)
	upgrade_branches.append(branch_1)
	upgrade_branches.append(branch_2)

func activate():
	if is_active:
		return
	
	is_active = true
	visible = true
	set_physics_process(true)
	_on_activated()
	print("Weapon activated: ", weapon_data.weapon_name if weapon_data else name)

func deactivate():
	if not is_active:
		return
	
	is_active = false
	visible = false
	set_physics_process(false)
	_on_deactivated()
	print("Weapon deactivated: ", weapon_data.weapon_name if weapon_data else name)

func _on_activated():
	# Переопределяется в дочерних классах
	pass

func _on_deactivated():
	# Переопределяется в дочерних классах
	pass

func can_attack() -> bool:
	return is_active and cooldown_timer <= 0.0

func attack(hit_type: Enums.HitType):
	if not can_attack() or not weapon_data:
		return
	
	total_attacks += 1
	if hit_type == Enums.HitType.PERFECT:
		perfect_hits += 1
	
	var damage_multiplier = _get_damage_multiplier(hit_type)
	var final_damage = weapon_data.base_damage * damage_multiplier
	
	_perform_attack(hit_type, final_damage)
	
	cooldown_timer = weapon_data.attack_cooldown * _get_cooldown_multiplier()
	attack_performed.emit(hit_type)

func _perform_attack(hit_type: Enums.HitType, damage: float):
	pass

func weapon_process(delta: float):
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			cooldown_ready.emit()
	
	_process_weapon_logic(delta)

func _process_weapon_logic(delta: float):
	pass

func on_missed_beat():
	pass

func upgrade(branch_index: int):
	if branch_index < 0 or branch_index >= upgrade_branches.size():
		return
	
	var branch = upgrade_branches[branch_index]
	branch.level += 1
	_apply_upgrade(branch_index, branch.level)

func get_branch_level(branch_index: int) -> int:
	if branch_index < 0 or branch_index >= upgrade_branches.size():
		return 0
	return upgrade_branches[branch_index].level

func _apply_upgrade(branch_index: int, level: int):
	pass

func _get_damage_multiplier(hit_type: Enums.HitType) -> float:
	var multiplier = 1.0
	match hit_type:
		Enums.HitType.PERFECT:
			multiplier = 1.5
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			multiplier = 1.0
	
	for branch in upgrade_branches:
		multiplier *= branch.get_damage_modifier()
	
	return multiplier

func _get_cooldown_multiplier() -> float:
	var multiplier = 1.0
	for branch in upgrade_branches:
		multiplier *= branch.get_cooldown_modifier()
	return multiplier


class UpgradeBranch:
	var branch_name: String
	var level: int = 0
	var max_level: int = 5
	var modifiers: Dictionary = {}
	
	func _init(name: String, max_lvl: int = 5):
		branch_name = name
		max_level = max_lvl
	
	func get_damage_modifier() -> float:
		return modifiers.get("damage_mult", 1.0)
	
	func get_cooldown_modifier() -> float:
		return modifiers.get("cooldown_mult", 1.0)
