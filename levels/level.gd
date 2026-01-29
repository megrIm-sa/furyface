extends Node2D

@onready var conductor: Conductor = $Conductor


func _ready() -> void:
	conductor.play()
