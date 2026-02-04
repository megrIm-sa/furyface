class_name DamageFlashComponent
extends Node

@export var target_sprite: Sprite2D
@export var flash_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var flash_duration: float = 0.15

var _original_modulate: Color = Color.WHITE
var _active_tween: Tween = null

func _ready() -> void:
	if target_sprite:
		_original_modulate = target_sprite.modulate

## Проигрывает эффект вспышки
func flash(custom_color: Color = Color.TRANSPARENT) -> void:
	if not target_sprite:
		push_warning("DamageFlashComponent: target_sprite not set!")
		return
	
	# Отменяем предыдущую анимацию
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
	
	var color_to_use = custom_color if custom_color != Color.TRANSPARENT else flash_color
	target_sprite.modulate = color_to_use
	
	_active_tween = create_tween()
	_active_tween.tween_property(target_sprite, "modulate", _original_modulate, flash_duration)

## Обновляет оригинальный цвет (полезно если спрайт меняет цвет не через flash)
func update_original_modulate(new_modulate: Color) -> void:
	_original_modulate = new_modulate
