class_name Player
extends CharacterBody2D

enum State { IDLE, WALK, DASH, DEAD }

@onready var sprite: Sprite2D = $Sprite2D
@onready var mask_sprite: Sprite2D = $MaskSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var damage_flash: DamageFlashComponent = $DamageFlashComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var dash: DashComponent = $DashComponent
@onready var anim_controller: PlayerAnimationController = $PlayerAnimationController
@onready var weapon_manager: WeaponManager = $WeaponManager
@onready var combo: ComboComponent = $ComboComponent
@onready var mask_ability: MaskAbilityManager = $MaskAbilityManager

var state: State = State.IDLE
var input_dir: Vector2 = Vector2.ZERO

# Переадресация сигналов для обратной совместимости
signal health_changed(current: float, maximum: float)
signal player_died()
signal dash_cooldown_changed(current: float, maximum: float)

func _enter_tree() -> void:
	add_to_group("player")

func _ready() -> void:
	_connect_component_signals()

func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	
	input_dir = _get_input_direction()
	
	# Обновляем facing к курсору
	anim_controller.update_facing_to_position(global_position, get_global_mouse_position())
	
	# Обрабатываем input
	_handle_input()
	
	# Обрабатываем состояния
	match state:
		State.IDLE:
			movement.stop_movement(self, delta)
			if input_dir != Vector2.ZERO:
				_change_state(State.WALK)
		
		State.WALK:
			movement.apply_movement(self, input_dir, delta)
			if input_dir == Vector2.ZERO:
				_change_state(State.IDLE)
		
		State.DASH:
			# DashComponent сам управляет velocity через _physics_process
			# Ничего не делаем здесь
			pass
		
		State.DEAD:
			movement.stop_movement(self, delta)
	
	move_and_slide()
	
	# Обновляем визуал
	anim_controller.update_sprite_flip()
	anim_controller.play_state_animation(_get_state_name(), velocity)

func _handle_input() -> void:
	var note_manager: NoteManager = get_tree().get_first_node_in_group("note_manager")
	if not note_manager:
		return
	
	# Dash
	if Input.is_action_just_pressed("dash"):
		var hit_type: Enums.HitType = note_manager.resolve_hit()
		_try_dash(hit_type)
	
	# Attack
	if Input.is_action_just_pressed("shoot"):
		if weapon_manager:
			print("shoot")
			weapon_manager.try_attack(note_manager)
	
	# Reload
	if Input.is_action_just_pressed("reload"):
		if weapon_manager:
			weapon_manager.try_reload()
	
	# Switch weapon
	if Input.is_action_just_pressed("switch_weapon"):
		_switch_weapon()


func _try_dash(hit_type: Enums.HitType) -> void:
	var success = dash.try_dash(
		hit_type,
		input_dir,
		anim_controller.facing_direction
	)
	
	if success:
		_change_state(State.DASH)

func _switch_weapon() -> void:
	if not weapon_manager or not weapon_manager.current_weapon:
		return
	
	var current_weapon = weapon_manager.current_weapon
	if not current_weapon.weapon_data:
		return
	
	var current_type = current_weapon.weapon_data.weapon_type
	var new_type = (
		Enums.WeaponType.REVOLVERS 
		if current_type == Enums.WeaponType.BLADE 
		else Enums.WeaponType.BLADE
	)
	weapon_manager.switch_weapon(new_type)

func _change_state(new_state: State) -> void:
	if state == new_state:
		return
	
	state = new_state

func _get_state_name() -> String:
	match state:
		State.IDLE: return "idle"
		State.WALK: return "walk"
		State.DASH: return "dash"
		State.DEAD: return "dead"
		_: return "idle"

func _get_input_direction() -> Vector2:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return dir.normalized()

# ============= COMPONENT SIGNAL CONNECTIONS =============

func _connect_component_signals() -> void:
	# Health
	if health:
		health.health_changed.connect(_on_health_changed)
		health.damage_taken.connect(_on_damage_taken)
		health.died.connect(_on_died)
	
	# Dash
	if dash:
		dash.dash_started.connect(_on_dash_started)
		dash.dash_finished.connect(_on_dash_finished)
		dash.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
	
	# WeaponManager
	if weapon_manager and mask_ability:
		weapon_manager.enemy_hit.connect(_on_weapon_enemy_hit)
		weapon_manager.weapon_fired.connect(_on_weapon_fired)
		weapon_manager.weapon_missed.connect(_on_weapon_missed)
	
	# Mask Ability
	if mask_ability:
		mask_ability.combo_component = combo
		mask_ability.weapon_manager = weapon_manager
		mask_ability.visual_parent = self
		
		mask_ability.mask_texture_changed.connect(_on_mask_texture_changed)
		mask_ability.ability_activated.connect(_on_ability_activated)
		mask_ability.ability_deactivated.connect(_on_ability_deactivated)

func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)

func _on_damage_taken(amount: float, source_position: Vector2, knockback_direction: Vector2) -> void:
	# Flash effect
	if damage_flash:
		damage_flash.flash()
	
	# Knockback (только если не в dash)
	if knockback_direction != Vector2.ZERO and state != State.DASH:
		velocity += knockback_direction.normalized() * 150.0

func _on_died() -> void:
	_change_state(State.DEAD)
	
	# Проигрываем анимацию смерти
	if anim_controller and anim_controller.animation_player:
		if anim_controller.animation_player.has_animation("death"):
			anim_controller.animation_player.play("death")
			await anim_controller.animation_player.animation_finished
	
	player_died.emit()

func _on_dash_started(hit_type: Enums.HitType) -> void:
	"""Вызывается когда начинается dash (DashComponent передает hit_type)"""
	# DashComponent сам управляет неуязвимостью через health_component
	# Ничего дополнительно делать не нужно
	pass

func _on_dash_finished() -> void:
	"""Вызывается когда dash завершается"""
	# Возвращаемся к нужному состоянию
	_change_state(State.WALK if input_dir != Vector2.ZERO else State.IDLE)

func _on_dash_cooldown_changed(current: float, maximum: float) -> void:
	dash_cooldown_changed.emit(current, maximum)

func _on_weapon_enemy_hit(enemy: Node2D, damage: float, hit_type: Enums.HitType) -> void:
	"""Вызывается когда оружие попадает по врагу"""
	if mask_ability:
		mask_ability.on_weapon_hit_enemy(enemy, damage, hit_type)

func _on_weapon_fired(weapon: Weapon, hit_type: Enums.HitType, damage: float) -> void:
	"""Вызывается при успешной атаке"""
	if combo:
		combo.process_hit(hit_type)

func _on_weapon_missed(weapon: Weapon, hit_type: Enums.HitType) -> void:
	"""Вызывается при промахе"""
	if combo:
		combo.process_hit(hit_type)

func _on_mask_texture_changed(texture: Texture2D) -> void:
	if mask_sprite:
		mask_sprite.texture = texture

func _on_ability_activated() -> void:
	pass

func _on_ability_deactivated() -> void:
	pass

# ============= PUBLIC API (для внешних скриптов) =============

## Наносит урон игроку
func take_damage(amount: float, source_position: Vector2, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if health:
		health.take_damage(amount, source_position, knockback_direction)
