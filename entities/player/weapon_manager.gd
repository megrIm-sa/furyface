class_name WeaponManager
extends Node2D

signal weapon_switched(weapon: Weapon)
signal weapon_fired(weapon: Weapon, hit_type: Enums.HitType, damage: float)
signal weapon_missed(weapon: Weapon, hit_type: Enums.HitType)
signal enemy_hit(enemy: Node2D, damage: float, hit_type: Enums.HitType)

@export_group("Configuration")
@export var starting_weapon: Enums.WeaponType = Enums.WeaponType.BLADE

@export_group("Scene References")
@export var weapon_container: Node2D

var current_weapon: Weapon
var weapons: Dictionary = {}

func _ready() -> void:
	if not weapon_container:
		weapon_container = get_node_or_null("WeaponContainer")
		if not weapon_container:
			push_error("WeaponManager: weapon_container not found!")
			return
	
	_register_weapons()
	switch_weapon(starting_weapon)

func _physics_process(delta: float) -> void:
	if current_weapon:
		current_weapon.weapon_process(delta)

func _register_weapons() -> void:
	"""Регистрирует все оружия из weapon_container"""
	for child in weapon_container.get_children():
		if child is Weapon:
			if child.weapon_data:
				weapons[child.weapon_data.weapon_type] = child
				child.deactivate()
				_connect_weapon_signals(child)
			else:
				push_warning("WeaponManager: Weapon '%s' has no weapon_data!" % child.name)

func _connect_weapon_signals(weapon: Weapon) -> void:
	"""Подключает сигналы оружия"""
	weapon.attack_performed.connect(_on_weapon_attack_performed)
	weapon.enemy_hit.connect(_on_weapon_enemy_hit)

func switch_weapon(weapon_type: Enums.WeaponType) -> void:
	"""Переключает активное оружие"""
	if current_weapon and current_weapon.weapon_data and current_weapon.weapon_data.weapon_type == weapon_type:
		return
	
	# Деактивируем текущее
	if current_weapon:
		current_weapon.deactivate()
	
	# Активируем новое
	if weapon_type in weapons:
		current_weapon = weapons[weapon_type]
		current_weapon.activate()
		weapon_switched.emit(current_weapon)
	else:
		push_warning("WeaponManager: weapon type %s not found!" % Enums.WeaponType.keys()[weapon_type])

func try_attack(note_manager: NoteManager) -> bool:
	"""Пытается атаковать текущим оружием"""
	if not current_weapon or not current_weapon.can_attack():
		return false
	
	var hit_type: Enums.HitType = note_manager.resolve_hit()
	
	# Успешные атаки
	if hit_type in [Enums.HitType.PERFECT, Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE]:
		current_weapon.attack(hit_type)
		return true
	
	# Промахи
	else:
		current_weapon.on_missed_beat()
		weapon_missed.emit(current_weapon, hit_type)
		return false

func try_reload() -> bool:
	"""Пытается перезарядить текущее оружие"""
	if not current_weapon:
		return false
	
	if current_weapon.has_method("manual_reload"):
		return current_weapon.manual_reload()
	
	return false

func get_weapon(weapon_type: Enums.WeaponType) -> Weapon:
	"""Возвращает оружие по типу"""
	return weapons.get(weapon_type, null)

# ============= SIGNAL HANDLERS =============

func _on_weapon_attack_performed(weapon: Weapon, hit_type: Enums.HitType, damage: float) -> void:
	weapon_fired.emit(weapon, hit_type, damage)

func _on_weapon_enemy_hit(enemy: Node2D, damage: float, hit_type: Enums.HitType) -> void:
	enemy_hit.emit(enemy, damage, hit_type)
