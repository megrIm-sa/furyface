# res://scripts/weapons/weapon_manager.gd
class_name WeaponManager
extends Node2D

signal weapon_switched(weapon_type: Enums.WeaponType)
signal weapon_fired(weapon: Weapon, hit_type: Enums.HitType)
signal weapon_upgraded(weapon: Weapon, branch: int, level: int)

@export var starting_weapon: Enums.WeaponType = Enums.WeaponType.BLADE
@export_group("Weapon Scenes")
@export var blade_scene: PackedScene
@export var revolvers_scene: PackedScene

var player: Player
var current_weapon: Weapon
var weapons: Dictionary = {}

@onready var weapon_container: Node2D = $WeaponContainer

func _ready():
	player = get_parent() as Player
	assert(player != null, "WeaponManager must be child of Player")
	
	_initialize_weapons()
	switch_weapon(starting_weapon)

func _input(event):
	# Обработка ручной перезарядки
	if event.is_action_pressed("reload"):
		try_reload()

func _initialize_weapons():
	print("=== Initializing Weapons ===")
	
	# Blade
	if blade_scene:
		print("Loading Blade scene...")
		var blade = blade_scene.instantiate() as Blade
		if blade:
			blade.weapon_manager = self
			weapon_container.add_child(blade)
			
			if blade.weapon_data:
				print("Blade weapon_data found: ", blade.weapon_data.weapon_name)
				print("Blade weapon_type: ", blade.weapon_data.weapon_type)
				weapons[blade.weapon_data.weapon_type] = blade
				blade.is_active = false
			else:
				push_warning("WeaponManager: Blade weapon_data not assigned!")
		else:
			push_warning("WeaponManager: Failed to instantiate Blade!")
	else:
		push_warning("WeaponManager: blade_scene not assigned!")
	
	# Revolvers
	if revolvers_scene:
		print("Loading Revolvers scene...")
		var revolvers = revolvers_scene.instantiate() as DualRevolvers
		if revolvers:
			revolvers.weapon_manager = self
			weapon_container.add_child(revolvers)
			
			if revolvers.weapon_data:
				print("Revolvers weapon_data found: ", revolvers.weapon_data.weapon_name)
				print("Revolvers weapon_type: ", revolvers.weapon_data.weapon_type)
				weapons[revolvers.weapon_data.weapon_type] = revolvers
				revolvers.is_active = false
			else:
				push_warning("WeaponManager: Revolvers weapon_data not assigned!")
		else:
			push_warning("WeaponManager: Failed to instantiate Revolvers!")
	else:
		push_warning("WeaponManager: revolvers_scene not assigned!")
	
	print("Total weapons loaded: ", weapons.size())
	print("Available weapon types: ", weapons.keys())
	
	# Деактивируем все оружия
	for weapon in weapons.values():
		weapon.deactivate()
		print("Deactivated weapon: ", weapon.name)
	
	print("=== Weapons Initialization Complete ===")

func switch_weapon(weapon_type: Enums.WeaponType):
	if current_weapon and current_weapon.weapon_data and current_weapon.weapon_data.weapon_type == weapon_type:
		return
	
	# Деактивируем текущее
	if current_weapon:
		current_weapon.deactivate()
	
	# Активируем новое
	if weapon_type in weapons:
		current_weapon = weapons[weapon_type]
		current_weapon.activate()
		weapon_switched.emit(weapon_type)
	else:
		push_warning("WeaponManager: weapon type %s not found!" % Enums.WeaponType.keys()[weapon_type])

func try_attack(note_manager: NoteManager) -> bool:
	if not current_weapon or not current_weapon.can_attack():
		return false
	
	var hit_type: Enums.HitType = note_manager.resolve_hit()
	
	if hit_type in [Enums.HitType.PERFECT, Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE]:
		current_weapon.attack(hit_type)
		weapon_fired.emit(current_weapon, hit_type)
		return true
	else:
		current_weapon.on_missed_beat()
		return false

func try_reload() -> bool:
	"""Пытается перезарядить текущее оружие"""
	if not current_weapon:
		return false
	
	# Проверяем, поддерживает ли оружие перезарядку
	if current_weapon.has_method("manual_reload"):
		return current_weapon.manual_reload()
	
	return false

func get_weapon(weapon_type: Enums.WeaponType) -> Weapon:
	return weapons.get(weapon_type, null)

func upgrade_weapon(weapon_type: Enums.WeaponType, branch: int):
	var weapon = get_weapon(weapon_type)
	if weapon:
		weapon.upgrade(branch)
		weapon_upgraded.emit(weapon, branch, weapon.get_branch_level(branch))

func get_player_position() -> Vector2:
	return player.global_position

func get_player_direction() -> Vector2:
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - player.global_position).normalized()
	
	if dir.length() < 0.1:
		dir = Vector2.RIGHT if not player.sprite.flip_h else Vector2.LEFT
	
	return dir

func _physics_process(delta):
	if current_weapon:
		current_weapon.weapon_process(delta)
