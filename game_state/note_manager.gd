class_name NoteManager
extends Control

signal note_hit(beat: float, hit_type: Enums.HitType, hit_error: float)

const NOTE_SCENE = preload("res://ui/note/note.tscn")
const HIT_MARGIN_PERFECT = 0.050
const HIT_MARGIN_GOOD = 0.150
const HIT_MARGIN_MISS = 0.300

@export var conductor: Conductor
@export var time_type: Enums.TimeType = Enums.TimeType .FILTERED

var _notes: Array[Note] = []
var _hit_error_acc: float = 0.0
var _hit_count: int = 0

# For dynamic note spawning every beat
var next_note_beat: float = 0.0
var lookahead_beats: float = 4.0  # Spawn notes this many beats ahead for visibility


func _process(_delta: float) -> void:
	var curr_beat := _get_curr_beat()
	
	# Dynamically spawn new notes every beat, if needed
	while next_note_beat < curr_beat + lookahead_beats:
		var note := NOTE_SCENE.instantiate() as Note
		note.beat = next_note_beat
		note.conductor = conductor
		note.update_beat(-100)
		add_child(note)
		_notes.append(note)
		next_note_beat += 1.0
	
	# Update all notes
	for i in range(_notes.size()):
		_notes[i].update_beat(curr_beat)
	
	_miss_old_notes()
	
	if Input.is_action_just_pressed(&"hit"):
		_handle_keypress()

func _miss_old_notes() -> void:
	while not _notes.is_empty():
		var note := _notes[0] as Note
		var note_delta := _get_note_delta(note)
		if note_delta > HIT_MARGIN_GOOD:
			# Time is past the note's hit window, miss.
			note.miss(false)
			_notes.remove_at(0)
			note_hit.emit(note.beat, Enums.HitType.MISS_LATE, note_delta)
		else:
			# Note is still hittable, so stop checking rest of the (later)
			# notes.
			break

func _handle_keypress() -> void:
	var note := _notes[0] as Note
	var hit_delta := _get_note_delta(note)
	if hit_delta < -HIT_MARGIN_MISS:
		# Note is not hittable, do nothing.
		pass
	elif -HIT_MARGIN_PERFECT <= hit_delta and hit_delta <= HIT_MARGIN_PERFECT:
		# Hit on time, perfect.
		note.hit_perfect()
		_notes.remove_at(0)
		_hit_error_acc += hit_delta
		_hit_count += 1
		note_hit.emit(note.beat, Enums.HitType.PERFECT, hit_delta)
	elif -HIT_MARGIN_GOOD <= hit_delta and hit_delta <= HIT_MARGIN_GOOD:
		# Hit slightly off time, good.
		note.hit_good()
		_notes.remove_at(0)
		_hit_error_acc += hit_delta
		_hit_count += 1
		if hit_delta < 0:
			note_hit.emit(note.beat, Enums.HitType.GOOD_EARLY, hit_delta)
		else:
			note_hit.emit(note.beat, Enums.HitType.GOOD_LATE, hit_delta)
	elif -HIT_MARGIN_MISS <= hit_delta and hit_delta <= HIT_MARGIN_MISS:
		# Hit way off time, miss.
		note.miss()
		_notes.remove_at(0)
		_hit_error_acc += hit_delta
		_hit_count += 1
		if hit_delta < 0:
			note_hit.emit(note.beat, Enums.HitType.MISS_EARLY, hit_delta)
		else:
			note_hit.emit(note.beat, Enums.HitType.MISS_LATE, hit_delta)

func _get_note_delta(note: Note) -> float:
	var curr_beat := _get_curr_beat()
	var beat_delta := curr_beat - note.beat
	return beat_delta * conductor.get_beat_duration()

func _get_curr_beat() -> float:
	var curr_beat: float
	match time_type:
		Enums.TimeType.FILTERED:
			curr_beat = conductor.get_current_beat()
		Enums.TimeType.RAW:
			curr_beat = conductor.get_current_beat_raw()
		_:
			assert(false, "Unknown TimeType: %s" % time_type)
			curr_beat = conductor.get_current_beat()
	# Adjust the timing for input delay. While this will shift the note
	# positions such that "on time" does not line up visually with the guide
	# sprite, the resulting visual is a lot smoother compared to readjusting the
	# note position after hitting it.
	curr_beat -= GlobalSettings.input_latency_ms / 1000.0 / conductor.get_beat_duration()
	return curr_beat
