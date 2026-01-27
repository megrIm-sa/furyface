extends TextureRect

@export_range(0.0, 1.0) var health : float:
	set(v):
		health = clamp(v, 0.0, 1.0)
		update_layout()

@export var blood_surface: ColorRect
@export var blood_fill: ColorRect

func _ready():
	update_layout()


func update_layout():
	if !blood_fill:
		return
		
	var fill_height := size.y * health
	blood_fill.position.y = size.y - fill_height
	blood_fill.size.y = fill_height

	# поверхность всегда сверху крови
	blood_surface.position.y = blood_fill.position.y - blood_surface.size.y * 0.5
