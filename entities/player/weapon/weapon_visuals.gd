# res://scripts/weapons/weapon_visuals.gd
class_name WeaponVisuals
extends Node2D

signal animation_finished()

@export var weapon_sprite: Texture2D
@export var sprite_offset: Vector2 = Vector2(10, 0)  # Смещение спрайта относительно руки
@export var sprite_rotation_offset: float = 0.0  # Доп. поворот спрайта

var sprite: Sprite2D
var hands_controller: HandsController

func _ready():
	# Создаём спрайт оружия
	sprite = Sprite2D.new()
	sprite.texture = weapon_sprite
	sprite.position = sprite_offset
	sprite.rotation = deg_to_rad(sprite_rotation_offset)
	add_child(sprite)
	
	# Находим HandsController
	var player = get_tree().get_first_node_in_group("player")
	if player:
		hands_controller = player.get_node_or_null("Hands")

func _process(_delta):
	if not hands_controller:
		return
	
	# Привязываем визуал к руке
	global_position = hands_controller.get_primary_hand_position()
	rotation = hands_controller.rotation
	
	# Flip спрайта в зависимости от направления
	_update_sprite_flip()

func _update_sprite_flip():
	var direction = hands_controller.get_hands_direction()
	
	# Если смотрим влево, переворачиваем спрайт по вертикали
	if direction.x < 0:
		sprite.flip_v = true
	else:
		sprite.flip_v = false

func play_attack_animation():
	"""Переопределяется в дочерних классах"""
	pass

func set_sprite_texture(texture: Texture2D):
	if sprite:
		sprite.texture = texture
