# res://scripts/weapons/dual_revolvers.gd
class_name DualRevolvers
extends Weapon

@export var revolver_gun_scene: PackedScene
@export var bullet_scene: PackedScene
@export var bullet_spawn_distance: float = 20.0  # Расстояние от оружия до точки выстрела

var current_ammo_left: int = 6
var current_ammo_right: int = 6
var use_left_gun: bool = true
var is_reloading: bool = false
var reload_timer: float = 0.0

var visuals: RevolverVisuals
var conductor: Conductor

func _ready():
	super._ready()
	_setup_visuals()
	
	conductor = get_tree().get_first_node_in_group("conductor")
	
	if not bullet_scene:
		bullet_scene = load("res://scenes/weapons/bullet.tscn")

func _setup_visuals():
	visuals = RevolverVisuals.new()
	visuals.revolver_scene = revolver_gun_scene
	add_child(visuals)
	
	visuals.active_offset = Vector2(0, 0)
	visuals.inactive_offset = Vector2(-15, 8)
	visuals.inactive_rotation = -30.0
	visuals.transition_speed = 15.0
	
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
	
	# Визуальная анимация выстрела
	if visuals:
		visuals.play_shoot_animation(use_left)
	
	# Стреляем
	_spawn_bullet(damage, hit_type)
	
	if not _has_ammo():
		_start_reload()

func _spawn_bullet(damage: float, hit_type: Enums.HitType):
	if not bullet_scene:
		return
	
	var revolver_data = weapon_data as RevolverResource
	if not revolver_data:
		return
	
	# Направление к курсору
	var direction = _get_shooting_direction()
	
	# Точка выстрела = позиция оружия + смещение в направлении курсора
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
	"""Возвращает направление от позиции оружия к курсору"""
	var mouse_pos = get_global_mouse_position()
	return (mouse_pos - global_position).normalized()

func _start_reload():
	if is_reloading:
		return
	
	is_reloading = true
	
	var revolver_data = weapon_data as RevolverResource
	if revolver_data and conductor:
		var beat_duration = conductor.get_beat_duration()
		reload_timer = revolver_data.reload_beats * beat_duration
	else:
		reload_timer = 1.5
	
	if visuals:
		visuals.play_reload_animation()

func _process_weapon_logic(delta: float):
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

func _finish_reload():
	var revolver_data = weapon_data as RevolverResource
	if revolver_data:
		current_ammo_left = revolver_data.max_ammo_per_gun
		current_ammo_right = revolver_data.max_ammo_per_gun
	
	is_reloading = false
	use_left_gun = true

func _on_activated():
	if visuals:
		visuals.visible = true

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
		"reload_progress": 1.0 - (reload_timer / (revolver_data.reload_beats * conductor.get_beat_duration())) if is_reloading and conductor and revolver_data else 1.0
	}
