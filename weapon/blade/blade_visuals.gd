# res://scripts/weapons/blade_visuals.gd
class_name BladeVisuals
extends Node2D

signal animation_finished()

@export var visual_scene: PackedScene
@export var slash_duration: float = 0.12
@export var slash_angle: float = 110.0
@export var windup_angle: float = -50.0
@export var hand_windup_offset: Vector2 = Vector2(-8, 2)
@export var hand_strike_offset: Vector2 = Vector2(12, -3)

var visual_instance: Node2D
var sprite: Sprite2D
var hands_controller: HandsController

var attack_tween: Tween
var is_flipped: bool = false
var hand_offset: Vector2 = Vector2.ZERO

func _ready():
	if visual_scene:
		visual_instance = visual_scene.instantiate()
		add_child(visual_instance)
		sprite = visual_instance.get_node_or_null("Sprite")
	
	if not sprite:
		push_error("BladeVisuals: Sprite not found in visual_scene!")
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		hands_controller = player.get_node_or_null("Hands")

func _process(_delta):
	if not hands_controller or not visual_instance:
		return
	
	var direction = hands_controller.get_hands_direction()
	var base_angle = hands_controller.get_hands_angle()
	
	rotation = base_angle
	
	var base_hand_position = hands_controller.get_primary_hand_position()
	var offset_rotated = hand_offset.rotated(base_angle)
	global_position = base_hand_position + offset_rotated
	
	# Обновляем flip
	if direction.x < 0:
		sprite.flip_v = true
		is_flipped = true
		sprite.offset.y = 10
	else:
		sprite.flip_v = false
		is_flipped = false
		sprite.offset.y = -10

func play_attack_animation():
	# Останавливаем предыдущую анимацию если она есть
	if attack_tween and attack_tween.is_valid():
		attack_tween.kill()
	
	var anim_windup = windup_angle
	var anim_slash = slash_angle
	var hand_windup = hand_windup_offset
	var hand_strike = hand_strike_offset
	
	if is_flipped:
		anim_windup = -windup_angle
		anim_slash = -slash_angle
		hand_windup.x = -hand_windup.x
		hand_strike.x = -hand_strike.x
	
	visual_instance.rotation = 0.0
	hand_offset = Vector2.ZERO
	
	attack_tween = create_tween()
	
	# ФАЗА 1: ЗАМАХ
	attack_tween.set_parallel(false)
	attack_tween.set_ease(Tween.EASE_OUT)
	attack_tween.set_trans(Tween.TRANS_CUBIC)
	
	attack_tween.tween_property(visual_instance, "rotation", deg_to_rad(anim_windup), slash_duration * 0.3)
	attack_tween.parallel().tween_property(self, "hand_offset", hand_windup, slash_duration * 0.3)
	
	# ФАЗА 2: УДАР
	attack_tween.set_ease(Tween.EASE_IN)
	attack_tween.set_trans(Tween.TRANS_EXPO)
	
	attack_tween.tween_property(visual_instance, "rotation", deg_to_rad(anim_slash), slash_duration * 0.25)
	attack_tween.parallel().tween_property(self, "hand_offset", hand_strike, slash_duration * 0.25)
	
	# ФАЗА 3: ВОЗВРАТ
	attack_tween.set_ease(Tween.EASE_OUT)
	attack_tween.set_trans(Tween.TRANS_BACK)
	
	attack_tween.tween_property(visual_instance, "rotation", 0.0, slash_duration * 0.45)
	attack_tween.parallel().tween_property(self, "hand_offset", Vector2.ZERO, slash_duration * 0.45)
	
	await attack_tween.finished
	visual_instance.rotation = 0.0
	hand_offset = Vector2.ZERO
	animation_finished.emit()

func set_visual_scene(scene: PackedScene):
	visual_scene = scene
	
	if visual_instance:
		visual_instance.queue_free()
	
	if visual_scene:
		visual_instance = visual_scene.instantiate()
		add_child(visual_instance)
		sprite = visual_instance.get_node_or_null("Sprite")
