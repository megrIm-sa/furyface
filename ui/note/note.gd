class_name Note
extends TextureRect

@export var movement_direction: Vector2 = Vector2(0, 1)
@export var target_position: Vector2 = Vector2.ZERO
@export var fade_window_beats: float = 1.5
@export var min_alpha: float = 0
@export var fade_after_center : float = 4.0

@export_category("Note Colors")
@export var perfect_note_color : Color = Color.YELLOW
@export var good_note_color : Color = Color.DEEP_SKY_BLUE
@export var miss_note_color : Color = Color.DARK_RED

@export_category("Note Scales")
@export var perfect_note_scale : float = 1.5
@export var good_note_scale : float = 1.2
@export var miss_note_scale : float = 0.5

var beat: int
var consumed: bool = false
var _speed: float
var _movement_paused := false
var _song_time_delta := 0.0


func _ready() -> void:
	_speed = GlobalSettings.scroll_speed
	GlobalSettings.scroll_speed_changed.connect(
		func(s): _speed = s
	)


func update_beat(beat_delta: float, beat_duration : float) -> void:
	if consumed or _movement_paused:
		return
	
	_song_time_delta = beat_delta * beat_duration
	
	var abs_time_delta: float = abs(_song_time_delta)
	var fade_window_seconds: float = fade_window_beats * beat_duration
	
	var fade := abs_time_delta / fade_window_seconds
	
	if _song_time_delta > 0.0:
		fade *= fade_after_center
	
	modulate.a = clamp(1.0 - fade, min_alpha, 1.0)
	
	_update_position()


func hit_perfect() -> void:
	consumed = true
	position = target_position
	_play_hit(perfect_note_color, perfect_note_scale)


func hit_good() -> void:
	consumed = true
	position = target_position
	_play_hit(good_note_color, good_note_scale)


func miss(stop := true) -> void:
	consumed = true
	_movement_paused = stop
	position = target_position
	_play_fade(miss_note_color, miss_note_scale)


func fade_out_naturally(time := 0.3) -> void:
	consumed = true
	_movement_paused = false
	
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, time)
	t.tween_callback(queue_free)


func _play_hit(color: Color, scale_mul: float) -> void:
	_movement_paused = true
	modulate = Color(color.r, color.g, color.b, 1.0)
	var t := create_tween()
	t.parallel().tween_property(self, "modulate:a", 0, 0.2)
	t.parallel().tween_property(self, "scale", Vector2.ONE * scale_mul, 0.2)
	t.tween_callback(_on_visual_complete)


func _play_fade(color: Color, time: float) -> void:
	modulate = Color(color.r, color.g, color.b, 1.0)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0, time)
	t.tween_callback(_on_visual_complete)


func _on_visual_complete() -> void:
	queue_free()


func _update_position() -> void:
	var displacement: float
	displacement = _speed * _song_time_delta
	position = target_position + movement_direction.normalized() * displacement
