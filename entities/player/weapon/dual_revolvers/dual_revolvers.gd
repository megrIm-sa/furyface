class_name DualRevolvers
extends Weapon

signal ammo_changed(left: int, right: int, max_per_gun: int)
signal reload_started(reload_duration: float)
signal reload_progress_updated(progress: float)
signal reload_finished()

@export_group("Revolver Configuration")
@export var bullet_scene: PackedScene
@export var bullet_spawn_distance: float = 20.0
@export var allow_partial_reload: bool = false

@export_group("Dependencies")
@export var visuals: RevolverVisuals

var current_ammo_left: int = 6
var current_ammo_right: int = 6
var use_left_gun: bool = true
var is_reloading: bool = false
var reload_timer: float = 0.0
var reload_duration: float = 0.0

var conductor: Conductor

func _ready() -> void:
	super._ready()
	
	# Автопоиск conductor
	conductor = get_tree().get_first_node_in_group("conductor")
	if not conductor:
		push_warning("DualRevolvers: Conductor not found!")
	
	# Подключаем сигналы визуалов
	if visuals:
		visuals.shoot_animation_finished.connect(_on_shoot_anim_finished)
		visuals.reload_animation_finished.connect(_on_reload_anim_finished)
	
	# Устанавливаем начальный патрон
	if weapon_data:
		var revolver_data = weapon_data as RevolverResource
		if revolver_data:
			current_ammo_left = revolver_data.max_ammo_per_gun
			current_ammo_right = revolver_data.max_ammo_per_gun
	
	_emit_ammo_changed()

func can_attack() -> bool:
	return super.can_attack() and not is_reloading and _has_ammo()

func manual_reload() -> bool:
	"""Ручная перезарядка по нажатию клавиши"""
	if is_reloading:
		return false
	
	if not allow_partial_reload and _is_ammo_full():
		return false
	
	_start_reload()
	return true

func _perform_attack(hit_type: Enums.HitType, damage: float) -> void:
	var use_left = false
	
	# Определяем какой револьвер стреляет
	if use_left_gun and current_ammo_left > 0:
		current_ammo_left -= 1
		use_left = true
	elif current_ammo_right > 0:
		current_ammo_right -= 1
		use_left = false
	else:
		_start_reload()
		return
	
	# Переключаем активный револьвер
	use_left_gun = !use_left_gun
	
	_emit_ammo_changed()
	
	# Проигрываем анимацию выстрела
	if visuals:
		visuals.play_shoot_animation(use_left)
	
	# Создаем пулю
	_spawn_bullet(damage, hit_type)
	
	# Если кончились патроны, начинаем перезарядку
	if not _has_ammo():
		_start_reload()

func _spawn_bullet(damage: float, hit_type: Enums.HitType) -> void:
	"""Создает и настраивает пулю"""
	if not bullet_scene:
		push_warning("DualRevolvers: bullet_scene not assigned!")
		return
	
	var revolver_data = weapon_data as RevolverResource
	if not revolver_data:
		return
	
	var direction = get_aim_direction()
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
	
	# Подключаемся к сигналу попадания пули
	bullet.body_hit.connect(func(body): _on_bullet_hit(body, damage, hit_type))

func _on_bullet_hit(body: Node2D, damage: float, hit_type: Enums.HitType) -> void:
	"""Вызывается когда пуля попадает в тело"""
	_notify_enemy_hit(body, damage, hit_type)

func _start_reload() -> void:
	"""Начинает перезарядку"""
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

func _process_weapon_logic(delta: float) -> void:
	"""Обрабатывает перезарядку"""
	if is_reloading:
		reload_timer -= delta
		
		var progress = 1.0 - (reload_timer / reload_duration) if reload_duration > 0.0 else 1.0
		reload_progress_updated.emit(clamp(progress, 0.0, 1.0))
		
		if reload_timer <= 0.0:
			_finish_reload()

func _finish_reload() -> void:
	"""Завершает перезарядку"""
	var revolver_data = weapon_data as RevolverResource
	if revolver_data:
		current_ammo_left = revolver_data.max_ammo_per_gun
		current_ammo_right = revolver_data.max_ammo_per_gun
	
	is_reloading = false
	use_left_gun = true
	
	_emit_ammo_changed()
	reload_finished.emit()

func _has_ammo() -> bool:
	"""Проверяет наличие патронов"""
	return current_ammo_left > 0 or current_ammo_right > 0

func _is_ammo_full() -> bool:
	"""Проверяет заполнены ли магазины"""
	var revolver_data = weapon_data as RevolverResource
	if not revolver_data:
		return true
	
	return current_ammo_left == revolver_data.max_ammo_per_gun and current_ammo_right == revolver_data.max_ammo_per_gun

func _emit_ammo_changed() -> void:
	"""Испускает сигнал об изменении патронов"""
	var revolver_data = weapon_data as RevolverResource
	var max_ammo = revolver_data.max_ammo_per_gun if revolver_data else 6
	ammo_changed.emit(current_ammo_left, current_ammo_right, max_ammo)

func _on_activated() -> void:
	if visuals:
		visuals.visible = true
	_emit_ammo_changed()

func _on_deactivated() -> void:
	if visuals:
		visuals.visible = false

func _on_shoot_anim_finished(is_left: bool) -> void:
	pass

func _on_reload_anim_finished() -> void:
	pass

func get_ammo_info() -> Dictionary:
	"""Возвращает информацию о патронах"""
	var revolver_data = weapon_data as RevolverResource
	return {
		"left": current_ammo_left,
		"right": current_ammo_right,
		"max_per_gun": revolver_data.max_ammo_per_gun if revolver_data else 6,
		"is_reloading": is_reloading,
		"reload_progress": 1.0 - (reload_timer / reload_duration) if is_reloading and reload_duration > 0.0 else 1.0
	}
