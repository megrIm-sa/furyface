class_name DualRevolvers
extends Weapon

@export var bullet_speed: float = 800.0
@export var max_ammo: int = 6
@export var reload_time: float = 1.5

var current_ammo_left: int = 6
var current_ammo_right: int = 6
var use_left_gun: bool = true  # Чередование револьверов
var is_reloading: bool = false
var reload_timer: float = 0.0

# Prefab пули
const BULLET_SCENE = preload("res://weapon/bullet.tscn")

func _ready():
	super._ready()
	weapon_name = "Dual Revolvers"
	weapon_type = Enums.WeaponType.REVOLVERS
	base_damage = 8.0
	attack_cooldown = 0.25
	range = 500.0

func _initialize_upgrade_branches():
	# Ветка 1: Gunslinger (скорострельность)
	var gunslinger_branch = UpgradeBranch.new("Gunslinger", 5)
	upgrade_branches.append(gunslinger_branch)
	
	# Ветка 2: Marksman (точность и урон)
	var marksman_branch = UpgradeBranch.new("Marksman", 5)
	upgrade_branches.append(marksman_branch)

func can_attack() -> bool:
	return super.can_attack() and not is_reloading and _has_ammo()

func _has_ammo() -> bool:
	return current_ammo_left > 0 or current_ammo_right > 0

func _perform_attack(hit_type: Enums.HitType, damage: float):
	# Определяем какой револьвер стреляет
	var gun_offset: Vector2
	
	if use_left_gun and current_ammo_left > 0:
		current_ammo_left -= 1
		gun_offset = Vector2(-10, 0)  # Смещение левого револьвера
	elif current_ammo_right > 0:
		current_ammo_right -= 1
		gun_offset = Vector2(10, 0)  # Смещение правого револьвера
	else:
		_start_reload()
		return
	
	# Чередуем револьверы
	use_left_gun = !use_left_gun
	
	# Стреляем
	var shoot_direction = weapon_manager.get_player_direction()
	_spawn_bullet(gun_offset, shoot_direction, damage, hit_type)
	
	# Автоматическая перезарядка если патроны кончились
	if not _has_ammo():
		_start_reload()

func _spawn_bullet(offset: Vector2, direction: Vector2, damage: float, hit_type: Enums.HitType):
	# TODO: Создайте сцену Bullet с соответствующим скриптом
	# var bullet = BULLET_SCENE.instantiate()
	# bullet.initialize(weapon_manager.get_player_position() + offset, direction, bullet_speed, damage)
	# get_tree().root.add_child(bullet)
	
	# Визуальные эффекты
	_play_shoot_animation(offset, direction)

func _play_shoot_animation(offset: Vector2, direction: Vector2):
	# TODO: Добавить эффект выстрела, отдачу и т.д.
	pass

func _start_reload():
	if is_reloading:
		return
	
	is_reloading = true
	reload_timer = reload_time

func _process_weapon_logic(delta: float):
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

func _finish_reload():
	current_ammo_left = max_ammo
	current_ammo_right = max_ammo
	is_reloading = false
	use_left_gun = true

func _apply_upgrade(branch_index: int, level: int):
	match branch_index:
		0:  # Gunslinger
			upgrade_branches[0].modifiers["cooldown_mult"] = 1.0 - level * 0.1
			max_ammo = 6 + level
		1:  # Marksman
			upgrade_branches[1].modifiers["damage_mult"] = 1.0 + level * 0.2
			bullet_speed = 800.0 + level * 50.0

func get_ammo_info() -> Dictionary:
	return {
		"left": current_ammo_left,
		"right": current_ammo_right,
		"is_reloading": is_reloading,
		"reload_progress": 1.0 - (reload_timer / reload_time) if is_reloading else 1.0
	}
