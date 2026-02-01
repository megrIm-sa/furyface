# res://scripts/weapons/dual_revolvers.gd
class_name DualRevolvers
extends Weapon

signal ammo_changed(left: int, right: int, max_per_gun: int)
signal reload_started(reload_duration: float)
signal reload_progress_updated(progress: float)

@export var revolver_gun_scene: PackedScene
@export var bullet_scene: PackedScene
@export var bullet_spawn_distance: float = 20.0
@export var allow_partial_reload: bool = false  # Разрешить перезарядку даже если не все патроны использованы

var current_ammo_left: int = 6
var current_ammo_right: int = 6
var use_left_gun: bool = true
var is_reloading: bool = false
var reload_timer: float = 0.0
var reload_duration: float = 0.0

var visuals: RevolverVisuals
var conductor: Conductor

func _ready():
	super._ready()
	_setup_visuals()
	
	conductor = get_tree().get_first_node_in_group("conductor")
	
	if not bullet_scene:
		bullet_scene = load("res://scenes/weapons/bullet.tscn")
	
	_emit_ammo_changed()

func _setup_visuals():
	visuals = RevolverVisuals.new()
	visuals.revolver_scene = revolver_gun_scene
	add_child(visuals)
	
	visuals.shoot_animation_finished.connect(_on_shoot_anim_finished)
	visuals.reload_animation_finished.connect(_on_reload_anim_finished)
	
	if weapon_data:
		var revolver_data = weapon_data as RevolverResource
		if revolver_data:
			current_ammo_left = revolver_data.max_ammo_per_gun
			current_ammo_right = revolver_data.max_ammo_per_gun

func can_attack() -> bool:
	return super.can_attack() and not is_reloading and _has_ammo()

func _has_ammo() -> bool:
	return current_ammo_left > 0 or current_ammo_right > 0

func _is_ammo_full() -> bool:
	"""Проверяет, заполнены ли оба магазина"""
	var revolver_data = weapon_data as RevolverResource
	if not revolver_data:
		return true
	
	return current_ammo_left == revolver_data.max_ammo_per_gun and current_ammo_right == revolver_data.max_ammo_per_gun

func manual_reload() -> bool:
	"""Ручная перезарядка по нажатию клавиши"""
	# Нельзя перезарядить если:
	# 1. Уже идет перезарядка
	if is_reloading:
		print("Already reloading!")
		return false
	
	# 2. Магазины полные (если не разрешена частичная перезарядка)
	if not allow_partial_reload and _is_ammo_full():
		print("Ammo is full!")
		return false
	
	# Начинаем перезарядку
	_start_reload()
	return true

func _perform_attack(hit_type: Enums.HitType, damage: float):
	var use_left = false
	
	if use_left_gun and current_ammo_left > 0:
		current_ammo_left -= 1
		use_left = true
	elif current_ammo_right > 0:
		current_ammo_right -= 1
		use_left = false
	else:
		_start_reload()
		return
	
	use_left_gun = !use_left_gun
	
	_emit_ammo_changed()
	
	if visuals:
		visuals.play_shoot_animation(use_left)
	
	_spawn_bullet(damage, hit_type)
	
	if not _has_ammo():
		_start_reload()

func _spawn_bullet(damage: float, hit_type: Enums.HitType):
	if not bullet_scene:
		return
	
	var revolver_data = weapon_data as RevolverResource
	if not revolver_data:
		return
	
	var direction = _get_shooting_direction()
	var spawn_position = global_position + direction * bullet_spawn_distance
	
	var bullet = bullet_scene.instantiate() as Bullet
	get_tree().root.add_child(bullet)
	
	bullet.initialize(
		spawn_position,
		direction,
		revolver_data.bullet_speed,
		damage,
		revolver_data.bullet_lifetime,
		revolver_data.bullet_trail_color
	)

func _get_shooting_direction() -> Vector2:
	var mouse_pos = get_global_mouse_position()
	return (mouse_pos - global_position).normalized()

func _start_reload():
	if is_reloading:
		return
	
	is_reloading = true
	
	var revolver_data = weapon_data as RevolverResource
	if revolver_data and conductor:
		var beat_duration = conductor.get_beat_duration()
		reload_duration = revolver_data.reload_beats * beat_duration
		reload_timer = reload_duration
	else:
		reload_duration = 1.5
		reload_timer = 1.5
	
	reload_started.emit(reload_duration)
	
	if visuals:
		visuals.play_reload_animation()
	
	print("Reloading... Duration: %.2f seconds (%.1f beats)" % [reload_duration, revolver_data.reload_beats if revolver_data else 0])

func _process_weapon_logic(delta: float):
	if is_reloading:
		reload_timer -= delta
		
		var progress = 1.0 - (reload_timer / reload_duration) if reload_duration > 0.0 else 1.0
		reload_progress_updated.emit(clamp(progress, 0.0, 1.0))
		
		if reload_timer <= 0.0:
			_finish_reload()

func _finish_reload():
	var revolver_data = weapon_data as RevolverResource
	if revolver_data:
		current_ammo_left = revolver_data.max_ammo_per_gun
		current_ammo_right = revolver_data.max_ammo_per_gun
	
	is_reloading = false
	use_left_gun = true
	
	_emit_ammo_changed()
	
	print("Reload complete!")

func _emit_ammo_changed():
	var revolver_data = weapon_data as RevolverResource
	var max_ammo = revolver_data.max_ammo_per_gun if revolver_data else 6
	ammo_changed.emit(current_ammo_left, current_ammo_right, max_ammo)

func _on_activated():
	if visuals:
		visuals.visible = true
	
	_emit_ammo_changed()

func _on_deactivated():
	if visuals:
		visuals.visible = false

func _on_shoot_anim_finished(is_left: bool):
	pass

func _on_reload_anim_finished():
	pass

func _apply_upgrade(branch_index: int, level: int):
	var revolver_data = weapon_data as RevolverResource
	if not revolver_data:
		return
	
	match branch_index:
		0:  # Gunslinger
			upgrade_branches[0].modifiers["cooldown_mult"] = 1.0 - level * 0.08
			revolver_data.max_ammo_per_gun = 6 + level
		1:  # Marksman
			upgrade_branches[1].modifiers["damage_mult"] = 1.0 + level * 0.15
			revolver_data.bullet_speed = 800.0 + level * 40.0

func get_ammo_info() -> Dictionary:
	var revolver_data = weapon_data as RevolverResource
	return {
		"left": current_ammo_left,
		"right": current_ammo_right,
		"max_per_gun": revolver_data.max_ammo_per_gun if revolver_data else 6,
		"is_reloading": is_reloading,
		"reload_progress": 1.0 - (reload_timer / reload_duration) if is_reloading and reload_duration > 0.0 else 1.0
	}
