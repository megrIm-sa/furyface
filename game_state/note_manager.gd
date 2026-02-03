class_name NoteManager
extends Control

signal note_hit(beat: float, hit_type: Enums.HitType, hit_error: float)

@export var conductor: Conductor
@export var time_type: Enums.TimeType = Enums.TimeType.FILTERED
@export var spawners: Array[NoteSpawner] = []

@export var lookahead_beats: float = 4.0

var next_note_beat: int = 0
var active_beat: float = 0.0


func _enter_tree() -> void:
	add_to_group("note_manager")


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for spawner in spawners:
		note_hit.connect(spawner.beat_pressed)


func _process(_delta: float) -> void:
	var curr_beat := _get_curr_beat()
	var beat_duration := conductor.get_beat_duration()
	
	while next_note_beat < curr_beat + lookahead_beats:
		for spawner in spawners:
			spawner.spawn_note(next_note_beat)
		next_note_beat += 1
	
	for spawner in spawners:
		spawner.update_beat_in_notes(
			curr_beat,
			beat_duration
		)
		spawner.miss_old_notes(
			curr_beat,
			beat_duration
		)


func resolve_hit() -> Enums.HitType:
	var curr_beat := _get_curr_beat()
	var beat_duration := conductor.get_beat_duration()
	active_beat = round(curr_beat)
	var delta := (curr_beat - active_beat) * beat_duration
	
	var hit_type: Enums.HitType
	if abs(delta) <= Constants.HIT_MARGIN_PERFECT:
		hit_type = Enums.HitType.PERFECT
	elif abs(delta) <= Constants.HIT_MARGIN_GOOD:
		hit_type = Enums.HitType.GOOD_EARLY if delta < 0 else Enums.HitType.GOOD_LATE
	else:
		hit_type = Enums.HitType.MISS_EARLY if delta < 0 else Enums.HitType.MISS_LATE
	
	var margin_beats: float = Constants.HIT_MARGIN_MISS / beat_duration if hit_type in [Enums.HitType.MISS_EARLY, Enums.HitType.MISS_LATE] else Constants.HIT_MARGIN_GOOD / beat_duration
	
	var any_hit := false
	for spawner in spawners:
		var note := spawner.get_active_note(curr_beat, margin_beats)
		if note:
			spawner.hit_note(hit_type)
			any_hit = true
	
	if any_hit:
		note_hit.emit(active_beat, hit_type, delta)
	
	return hit_type


func _get_note_delta() -> float:
	return (_get_curr_beat() - active_beat) * conductor.get_beat_duration()


func _get_curr_beat() -> float:
	var beat := (
		conductor.get_current_beat()
		if time_type == Enums.TimeType.FILTERED
		else conductor.get_current_beat_raw()
	)

	beat -= (
		GlobalSettings.input_latency_ms
		/ 1000.0
		/ conductor.get_beat_duration()
	)

	return beat
