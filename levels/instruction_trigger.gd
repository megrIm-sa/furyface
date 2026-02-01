# res://scripts/triggers/instruction_trigger.gd
class_name InstructionTrigger
extends Area2D

@export var instruction_panel: CanvasLayer  # Дочерняя нода с текстом

func _ready():
	collision_layer = 0
	collision_mask = 1  # Слой игрока
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Скрываем панель по умолчанию
	if instruction_panel:
		instruction_panel.hide()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player") and instruction_panel:
		instruction_panel.show()

func _on_body_exited(body: Node2D):
	if body.is_in_group("player") and instruction_panel:
		instruction_panel.hide()
