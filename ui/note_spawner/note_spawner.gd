class_name NoteSpawner
extends TextureRect

const BEAT_PRESS_SCALE = 1.2

@export var note_scene : PackedScene
@export var movement_direction: Vector2 = Vector2(0, 1)
@export var offset: Vector2 = Vector2.ZERO

var _guide_tween: Tween
var _notes : Array[Note]


func update_beat_in_notes(curr_beat: float, beat_duration: float) -> void:
	for i in range(_notes.size() - 1, -1, -1):
		var note := _notes[i]
		if note.consumed:
			_notes.remove_at(i)
			continue
		
		var beat_delta := curr_beat - note.beat
		note.update_beat(beat_delta, beat_duration)


func spawn_note(beat: int) -> void:
	var note: Note = note_scene.instantiate()
	note.beat = beat
	note.movement_direction = movement_direction
	note.target_position = offset
	note.flip_h = flip_h
	note.update_beat(-100, -100)
	add_child(note)
	_notes.append(note)


func hit_note(hit_type : Enums.HitType) -> void:
	if _notes.is_empty():
		return
	
	var note : Note = _notes.pop_front()
	if hit_type == Enums.HitType.PERFECT:
		note.hit_perfect()
	elif hit_type in [Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE]:
		note.hit_good()
	else:
		note.miss()


func sort_notes() -> void:
	_notes.sort_custom(func(a, b): return a.beat < b.beat)


func beat_pressed(_beat: float, _hit_type: Enums.HitType, _hit_error: float) -> void:
	scale = BEAT_PRESS_SCALE * Vector2.ONE
	if _guide_tween:
		_guide_tween.kill()
	_guide_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_guide_tween.tween_property(self, ^"scale", Vector2.ONE, 0.2)


func miss_old_notes(curr_beat : float, beat_duration : float):
	var margin_beats = Constants.HIT_MARGIN_GOOD / beat_duration
	while not _notes.is_empty():
		var note := _notes[0]
		if curr_beat - note.beat > margin_beats:
			_notes.pop_front()
			note.fade_out_naturally()
		else:
			break


func get_active_note(curr_beat: float, margin_beats: float) -> Note:
	if _notes.is_empty():
		return null

	var note := _notes[0]
	if abs(curr_beat - note.beat) <= margin_beats:
		return note

	return null
