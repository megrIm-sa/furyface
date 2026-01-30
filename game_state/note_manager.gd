class_name NoteManager
extends Control

signal note_hit(beat: float, hit_type: Enums.HitType, hit_error: float)

const NOTE_SCENE = preload("res://ui/note/note.tscn")
const HIT_MARGIN_PERFECT = 0.025
const HIT_MARGIN_GOOD = 0.075
const HIT_MARGIN_MISS = 0.300

@export var conductor: Conductor
@export var time_type: Enums.TimeType = Enums.TimeType.FILTERED
@export var spawners: Array[NoteSpawner] = []  # Спавнеры нот (2 на экране)

var _all_notes: Array[Note] = []
var _hit_error_acc: float = 0.0
var _hit_count: int = 0

# For dynamic note spawning every beat
var next_note_beat: float = 0.0
var lookahead_beats: float = 4.0  # Spawn notes this many beats ahead for visibility

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE  # Не поглощать input, если не нужно
	for spawner in spawners:
		spawner.mouse_filter = MOUSE_FILTER_IGNORE  # То же для спавнеров

func _process(_delta: float) -> void:
	var curr_beat := _get_curr_beat()
	
	# Dynamically spawn new notes every beat, if needed
	while next_note_beat < curr_beat + lookahead_beats:
		for spawner in spawners:
			var note : Note = NOTE_SCENE.instantiate() as Note
			note.beat = next_note_beat
			note.conductor = conductor
			note.movement_direction = spawner.movement_direction
			note.target_position = spawner.offset
			note.flip_h = spawner.flip_h
			note.update_beat(-100)
			spawner.add_child(note)
			_all_notes.append(note)
			print(_all_notes.size())
		next_note_beat += 1.0
	
	# Sort all notes by beat (for handling earliest first)
	_all_notes.sort_custom(func(a: Note, b: Note): return a.beat < b.beat)
	
	# Update all notes
	for note in _all_notes:
		note.update_beat(curr_beat)
	
	_miss_old_notes()
	
	if Input.is_action_just_pressed(&"hit"):
		_handle_keypress()

func _miss_old_notes() -> void:
	while not _all_notes.is_empty():
		var note := _all_notes[0] as Note
		var note_delta := _get_note_delta(note)
		if note_delta > HIT_MARGIN_GOOD:
			# Просто исчезает без сигнала miss
			note._play_fade(Color.WHITE, 0.2)  # Нейтральный fade
			_all_notes.remove_at(0)
		else:
			# Note is still hittable, so stop checking rest of the (later)
			# notes.
			break

func _handle_keypress() -> void:
	var hit_notes: Array[Dictionary] = []
	var curr_beat := _get_curr_beat()
	
	for note in _all_notes:
		var hit_delta := (curr_beat - note.beat) * conductor.get_beat_duration()
		if abs(hit_delta) <= HIT_MARGIN_MISS:
			hit_notes.append({"note": note, "delta": hit_delta})
	
	if hit_notes.is_empty():
		print("No notes in hit window!")  # Debug: Если ничего не хитается
		return
	
	# Sort by abs(delta) to find closest
	hit_notes.sort_custom(func(a, b): return abs(a.delta) < abs(b.delta))
	
	# Hit all notes in window, update stats for all
	var to_remove: Array[Note] = []
	for h in hit_notes:
		var d: float = h.delta
		var n: Note = h.note
		if abs(d) <= HIT_MARGIN_PERFECT:
			n.hit_perfect()
			_hit_error_acc += d
			_hit_count += 1
		elif abs(d) <= HIT_MARGIN_GOOD:
			n.hit_good()
			_hit_error_acc += d
			_hit_count += 1
		else:
			n.miss()
			_hit_error_acc += d
			_hit_count += 1
		to_remove.append(n)
	
	# Remove after loop
	for n in to_remove:
		_all_notes.erase(n)
	
	# Emit only one signal for the closest note
	var closest = hit_notes[0]
	var hit_type: Enums.HitType
	if abs(closest.delta) <= HIT_MARGIN_PERFECT:
		hit_type = Enums.HitType.PERFECT
	elif abs(closest.delta) <= HIT_MARGIN_GOOD:
		if closest.delta < 0:
			hit_type = Enums.HitType.GOOD_EARLY
		else:
			hit_type = Enums.HitType.GOOD_LATE
	else:
		if closest.delta < 0:
			hit_type = Enums.HitType.MISS_EARLY
		else:
			hit_type = Enums.HitType.MISS_LATE
	note_hit.emit(closest.note.beat, hit_type, closest.delta)

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
