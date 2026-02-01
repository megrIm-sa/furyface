# res://scripts/level.gd
class_name Level
extends Node2D

@onready var conductor: Conductor = $Conductor

@export var player: Player
@export var boss: FearMaskBoss
@export var boss_reward_mask: Enums.MaskType

func _ready() -> void:
	conductor.play()
	
	# Подключаемся к событиям
	if player:
		player.player_died.connect(_on_player_died)
	
	if boss:
		boss.died.connect(_on_boss_died)
	
func _on_player_died():
	"""Перезапускает уровень при смерти игрока"""
	print("[Level] Player died, restarting level...")
	
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func _on_boss_died():
	"""Разблокирует новую маску и перезапускает уровень"""
	print("[Level] Boss defeated! Unlocking new mask...")
	
	# Сохраняем маску босса как разблокированную
	if boss_reward_mask:
		GlobalSettings.mask = boss_reward_mask
		print("[Level] Fear Mask unlocked!")
	
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
