class_name Note
extends Control

@export var x_offset: float = 0.0

var beat: float = 0.0
var conductor: Conductor

var _speed: float
var _movement_paused := false
var _song_time_delta := 0.0


func _ready() -> void:
	_speed = GlobalSettings.scroll_speed
	GlobalSettings.scroll_speed_changed.connect(
		func(s): _speed = s
	)


func activate(new_beat: float, new_conductor: Conductor) -> void:
	beat = new_beat
	conductor = new_conductor
	_movement_paused = false
	modulate = Color.WHITE
	visible = true
	scale = Vector2.ONE


func reset() -> void:
	visible = false
	_movement_paused = true


func update_beat(curr_beat: float) -> void:
	if _movement_paused:
		return

	_song_time_delta = (curr_beat - beat) * conductor.get_beat_duration()
	_update_position()


func hit_perfect() -> void:
	_play_hit(Color.YELLOW, 1.5)


func hit_good() -> void:
	_play_hit(Color.DEEP_SKY_BLUE, 1.2)


func miss(stop := true) -> void:
	_movement_paused = stop
	_play_fade(Color.DARK_RED, 0.5)


func _play_hit(color: Color, scale_mul: float) -> void:
	_movement_paused = true
	modulate = color

	var t := create_tween()
	t.parallel().tween_property(self, "modulate:a", 0, 0.2)
	t.parallel().tween_property(self, "scale", Vector2.ONE * scale_mul, 0.2)
	t.tween_callback(reset)


func _play_fade(color: Color, time: float) -> void:
	modulate = color
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0, time)
	t.tween_callback(reset)


func _update_position() -> void:
	var y: float
	if _song_time_delta > 0:
		y = _speed * _song_time_delta - _speed * pow(_song_time_delta, 2)
	else:
		y = _speed * _song_time_delta

	position = Vector2(x_offset, y)
