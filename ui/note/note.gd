class_name Note
extends TextureRect

var beat: float = 0.0
var conductor: Conductor
var _speed: float
var _movement_paused := false
var _song_time_delta := 0.0

@export var movement_direction: Vector2 = Vector2(0, 1)  # Направление движения (нормализованный вектор)
@export var target_position: Vector2 = Vector2.ZERO  # Точка нажатия (относительно родителя)
@export var fade_window_beats: float = 2  # Окно в битах для fade (ширина полной видимости)
@export var min_alpha: float = 0  # Минимальная прозрачность дальних нот

func _ready() -> void:
	_speed = GlobalSettings.scroll_speed
	GlobalSettings.scroll_speed_changed.connect(
		func(s): _speed = s
	)

func activate(new_beat: float, new_conductor: Conductor) -> void:
	beat = new_beat
	conductor = new_conductor
	_movement_paused = false
	modulate = Color(1, 1, 1, 1)  # Полная видимость
	visible = true
	scale = Vector2.ONE

func reset() -> void:
	visible = false
	_movement_paused = true
	modulate.a = 1.0  # Сброс для следующего актива

func update_beat(curr_beat: float) -> void:
	if _movement_paused:
		return
	_song_time_delta = (curr_beat - beat) * conductor.get_beat_duration()
	
	# Изменение прозрачности по близости к hit point (delta=0)
	var abs_time_delta: float = abs(_song_time_delta)
	var fade_window_seconds: float = fade_window_beats * conductor.get_beat_duration()
	modulate.a = clamp(1.0 - (abs_time_delta / fade_window_seconds), min_alpha, 1.0)
	
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
	modulate = Color(color.r, color.g, color.b, 1.0)
	var t := create_tween()
	t.parallel().tween_property(self, "modulate:a", 0, 0.2)
	t.parallel().tween_property(self, "scale", Vector2.ONE * scale_mul, 0.2)
	t.tween_callback(reset)

func _play_fade(color: Color, time: float) -> void:
	modulate = Color(color.r, color.g, color.b, 1.0)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0, time)
	t.tween_callback(reset)

func _update_position() -> void:
	var displacement: float
	if _song_time_delta > 0:
		displacement = _speed * _song_time_delta - _speed * pow(_song_time_delta, 2)
	else:
		displacement = _speed * _song_time_delta
	position = target_position + movement_direction.normalized() * displacement
