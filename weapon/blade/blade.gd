class_name Blade
extends Weapon

@export var debug_draw: bool = true
@export var blade_visual_scene: PackedScene

var attack_area: Area2D
var last_attack_direction: Vector2 = Vector2.RIGHT
var attack_visual_timer: float = 0.0
var attack_visual_duration: float = 0.2

var visuals: BladeVisuals
var slash_vfx: BladeSlashVFX  # Добавили VFX

func _ready():
	super._ready()
	_setup_hitbox()
	_setup_visuals()
	_setup_vfx()  # Новое

func _setup_vfx():
	slash_vfx = BladeSlashVFX.new()
	add_child(slash_vfx)
	
	if weapon_data:
		var blade_data = weapon_data as BladeResource
		if blade_data:
			slash_vfx.max_distance = blade_data.range  # Было arc_radius
			slash_vfx.arc_angle = blade_data.slash_arc  # Угол конуса
			slash_vfx.wave_thickness = 8.0  # Было arc_thickness
			slash_vfx.lifetime = 0.25
			slash_vfx.wave_speed = 600.0
			
			# Настройки пикселизации
			slash_vfx.use_pixelation = true
			slash_vfx.pixel_size = 1.0
			
			# Цвета (опционально)
			slash_vfx.wave_color = Color(0.8, 0.9, 1.0, 0.8)
			slash_vfx.trail_color = Color(0.5, 0.7, 1.0, 0.4)



func _setup_visuals():
	if not blade_visual_scene:
		push_warning("Blade: blade_visual_scene not assigned!")
		return
	
	visuals = BladeVisuals.new()
	visuals.visual_scene = blade_visual_scene
	add_child(visuals)
	
	if weapon_data:
		var blade_data = weapon_data as BladeResource
		if blade_data:
			visuals.slash_duration = blade_data.slash_animation_duration
			visuals.slash_angle = blade_data.slash_animation_angle
			visuals.windup_angle = -50.0

func _setup_hitbox():
	if not weapon_data:
		return
	
	attack_area = Area2D.new()
	attack_area.name = "AttackArea"
	add_child(attack_area)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = weapon_data.range
	collision.shape = shape
	collision.name = "CollisionShape2D"
	attack_area.add_child(collision)
	
	attack_area.monitoring = false
	attack_area.collision_layer = 0
	attack_area.collision_mask = 2

func _perform_attack(hit_type: Enums.HitType, damage: float):
	if not weapon_data:
		return
	
	var blade_data = weapon_data as BladeResource
	if not blade_data:
		return
	
	var attack_direction = weapon_manager.get_player_direction()
	last_attack_direction = attack_direction
	
	# Запускаем визуальную анимацию меча
	if visuals:
		visuals.play_attack_animation()
	
	# Запускаем VFX слеша с правильными параметрами
	if slash_vfx:
		slash_vfx.play_slash(
			attack_direction,      # Направление
			blade_data.slash_arc,  # Угол конуса
			blade_data.range       # Дальность волны
		)
	
	# Выполняем удар
	_perform_slash(attack_direction, damage, blade_data)
	
	attack_visual_timer = attack_visual_duration


func _perform_slash(direction: Vector2, damage: float, blade_data: BladeResource):
	attack_area.force_update_transform()
	attack_area.monitoring = true
	
	await get_tree().physics_frame
	
	var all_bodies = attack_area.get_overlapping_bodies()
	
	for body in all_bodies:
		if body.has_method("take_damage") and _is_in_slash_arc(body, direction, blade_data.slash_arc):
			var knockback_velocity = direction.normalized() * blade_data.knockback_force
			body.take_damage(damage, global_position, knockback_velocity)
	
	attack_area.monitoring = false

func _is_in_slash_arc(enemy: Node2D, attack_direction: Vector2, arc: float) -> bool:
	var to_enemy = (enemy.global_position - global_position).normalized()
	var angle = attack_direction.angle_to(to_enemy)
	return abs(angle) <= deg_to_rad(arc / 2.0)

func _process_weapon_logic(delta: float):
	if attack_visual_timer > 0.0:
		attack_visual_timer -= delta
	
	if debug_draw:
		queue_redraw()

func _on_activated():
	if visuals:
		visuals.visible = true
	if debug_draw:
		queue_redraw()
	print("Blade visuals activated")

func _on_deactivated():
	if visuals:
		visuals.visible = false
	print("Blade visuals deactivated")

func _draw():
	if not debug_draw or not is_active or not weapon_data:
		return
	
	var blade_data = weapon_data as BladeResource
	if not blade_data:
		return
	
	var range_val = blade_data.range
	
	# Радиус атаки
	draw_circle(Vector2.ZERO, range_val, Color(0, 1, 0, 0.05))
	draw_arc(Vector2.ZERO, range_val, 0, TAU, 32, Color(0, 1, 0, 0.3), 1.0)
	
	# Дуга атаки
	var half_arc = deg_to_rad(blade_data.slash_arc / 2.0)
	var direction_angle = last_attack_direction.angle()
	
	var arc_color: Color
	if attack_visual_timer > 0.0:
		arc_color = Color(1, 0, 0, 0.4)
	elif can_attack():
		arc_color = Color(0, 1, 0, 0.2)
	else:
		arc_color = Color(1, 1, 0, 0.15)
	
	draw_arc(Vector2.ZERO, range_val, direction_angle - half_arc, direction_angle + half_arc, 32, arc_color, 2.0)

func _apply_upgrade(branch_index: int, level: int):
	match branch_index:
		0:
			upgrade_branches[0].modifiers["damage_mult"] = 1.0 + level * 0.15
		1:
			upgrade_branches[1].modifiers["damage_mult"] = 1.0 + level * 0.25
			upgrade_branches[1].modifiers["cooldown_mult"] = 1.0 - level * 0.05
