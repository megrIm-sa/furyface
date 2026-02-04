class_name ShockwaveVisualizer
extends Node2D

@export_group("Visual Settings")
@export var shockwave_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var fill_alpha: float = 0.3
@export var border_width: float = 4.0
@export var inner_border_width: float = 2.0
@export var inner_border_offset: float = 5.0

@export_group("Animation")
@export var expansion_duration: float = 0.3
@export var fade_duration: float = 0.3

var is_active: bool = false
var current_radius: float = 0.0
var current_alpha: float = 0.0
var max_radius: float = 50.0

var shockwave_tween: Tween

func play_shockwave(radius: float) -> void:
	"""Запускает анимацию ударной волны"""
	# ИСПРАВЛЕНО: если уже активна, отменяем предыдущую
	if is_active and shockwave_tween and shockwave_tween.is_running():
		shockwave_tween.kill()
	
	is_active = true
	max_radius = radius
	current_radius = 0.0
	current_alpha = shockwave_color.a  # Сбрасываем альфу
	visible = true
	
	shockwave_tween = create_tween()
	shockwave_tween.set_parallel(true)
	
	# Расширение радиуса
	shockwave_tween.tween_property(self, "current_radius", max_radius, expansion_duration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	
	# Затухание альфы
	shockwave_tween.tween_property(self, "current_alpha", 0.0, fade_duration)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_QUAD)
	
	shockwave_tween.finished.connect(_on_shockwave_finished, CONNECT_ONE_SHOT)

func _on_shockwave_finished() -> void:
	"""Вызывается по завершении анимации"""
	is_active = false
	visible = false
	current_radius = 0.0
	current_alpha = 0.0


func _process(_delta: float) -> void:
	if is_active:
		queue_redraw()

func _draw() -> void:
	if not is_active or current_radius <= 0.0:
		return
	
	# Заполненный круг
	var fill_color = Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, current_alpha * fill_alpha)
	draw_circle(Vector2.ZERO, current_radius, fill_color)
	
	# Внешний контур
	var border_color = Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, current_alpha)
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, border_color, border_width)
	
	# Внутренний контур
	if current_radius > inner_border_offset:
		var inner_radius = current_radius - inner_border_offset
		var inner_color = Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, current_alpha * 0.5)
		draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 32, inner_color, inner_border_width)
