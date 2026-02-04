class_name Enemy
extends CharacterBody2D

signal state_changed(old_state: String, new_state: String)

@export var enemy_data: EnemyResource

@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var damage_flash: DamageFlashComponent = $DamageFlashComponent
@onready var beat_sync: BeatSyncComponent = $BeatSyncComponent
@onready var targeting: TargetingComponent = $TargetingComponent
@onready var anim_controller: EnemyAnimationController = $EnemyAnimationController

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var current_state: String = "idle"

func _ready() -> void:
	if not enemy_data:
		push_error("Enemy: enemy_data not assigned!")
		return
	
	_configure_components()
	_connect_signals()
	_apply_visuals()
	
	await get_tree().process_frame
	_on_ready()

func _configure_components() -> void:
	"""Настраивает компоненты из enemy_data"""
	if health:
		health.max_health = enemy_data.max_health
	
	if movement:
		movement.move_speed = enemy_data.move_speed
	
	if targeting:
		targeting.detection_range = enemy_data.detection_range
		targeting.attack_range = enemy_data.attack_range

func _connect_signals() -> void:
	"""Подключает сигналы компонентов"""
	if health:
		health.damage_taken.connect(_on_damage_taken)
		health.died.connect(_on_died)
	
	if beat_sync:
		beat_sync.beat_occurred.connect(_on_beat)

func _apply_visuals() -> void:
	"""Применяет визуальные настройки из enemy_data"""
	if enemy_data.sprite and sprite:
		sprite.texture = enemy_data.sprite
	
	if sprite:
		sprite.scale = Vector2.ONE * enemy_data.scale_size

func _physics_process(delta: float) -> void:
	if health and health.is_dead:
		return
	
	_process_state(delta)
	
	move_and_slide()
	_update_visuals(delta)

func _process_state(_delta: float) -> void:
	"""Переопределите в дочерних классах"""
	pass

func _on_beat(_beat: int) -> void:
	"""Переопределите в дочерних классах"""
	pass

func _on_ready() -> void:
	"""Переопределите в дочерних классах"""
	pass

func _update_visuals(_delta: float) -> void:
	"""Обновляет визуалы"""
	if anim_controller and targeting:
		# Обновляем flip
		var direction = targeting.get_direction_to_target()
		if direction != Vector2.ZERO:
			anim_controller.update_flip(direction)
		
		# Обновляем анимацию на основе скорости
		anim_controller.update_animation_from_velocity(velocity)

## Меняет состояние
func change_state(new_state: String) -> void:
	if current_state == new_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	_on_state_changed(old_state, new_state)
	state_changed.emit(old_state, new_state)

func _on_state_changed(_old_state: String, _new_state: String) -> void:
	"""Переопределите в дочерних классах"""
	pass

func _on_damage_taken(amount: float, source_position: Vector2, knockback_direction: Vector2) -> void:
	"""Обрабатывает получение урона"""
	# Вспышка повреждения
	if damage_flash:
		damage_flash.flash()
	
	# Применяем knockback
	if knockback_direction != Vector2.ZERO and enemy_data:
		velocity += knockback_direction * enemy_data.knockback_resistance

func _on_died() -> void:
	"""Обрабатывает смерть"""
	change_state("dead")
	
	# Отключаем коллизии
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	# Проигрываем анимацию смерти
	if anim_controller:
		anim_controller.play_death()
	
	# Удаляем через время
	await get_tree().create_timer(2.0).timeout
	queue_free()
