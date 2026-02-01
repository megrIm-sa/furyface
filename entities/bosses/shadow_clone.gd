# res://scripts/enemies/shadow_clone.gd
class_name ShadowClone
extends Node2D

var boss: FearMaskBoss
var target: Player
var lifetime: float = 3.0
var has_attacked: bool = false

@onready var sprite: Sprite2D = Sprite2D.new()
@onready var attack_timer: Timer = Timer.new()

func _ready():
	# Визуал
	add_child(sprite)
	sprite.modulate = Color(0.5, 0.3, 0.7, 0.6)  # Полупрозрачный фиолетовый
	# Используйте спрайт босса или отдельный
	
	# Таймер атаки
	add_child(attack_timer)
	attack_timer.wait_time = 1.0
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_perform_attack)
	attack_timer.start()
	
	# Автоудаление
	await get_tree().create_timer(lifetime).timeout
	_dissolve()

func _perform_attack():
	"""Выполняет атаку клона"""
	if has_attacked or not target:
		return
	
	has_attacked = true
	
	# Создаем опасную зону между клоном и игроком
	var danger_zone = DangerZone.new()
	danger_zone.shape = DangerZone.Shape.RECTANGLE
	
	var to_target = target.global_position - global_position
	danger_zone.rect_size = Vector2(to_target.length(), 60.0)
	danger_zone.rotation = to_target.angle()
	danger_zone.global_position = global_position + to_target / 2
	
	danger_zone.warning_duration = 0.5
	danger_zone.active_duration = 0.2
	
	get_parent().add_child(danger_zone)
	
	danger_zone.zone_activated.connect(func():
		if danger_zone.check_if_player_inside(target.global_position):
			target.take_damage(20.0, global_position, to_target.normalized() * 250.0)
	)

func _dissolve():
	"""Эффект растворения"""
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()
