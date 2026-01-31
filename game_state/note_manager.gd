class_name NoteManager
extends Control

signal note_hit(beat: float, hit_type: Enums.HitType, hit_error: float)

const NOTE_SCENE = preload("res://ui/note/note.tscn")
const HIT_MARGIN_PERFECT = 0.050
const HIT_MARGIN_GOOD = 0.150
const HIT_MARGIN_MISS = 0.500

@export var conductor: Conductor
@export var time_type: Enums.TimeType = Enums.TimeType.FILTERED
@export var spawners: Array[NoteSpawner] = []

var _all_notes: Array[Note] = []
var next_note_beat: float = 0.0
var lookahead_beats: float = 4.0

#var song_beat : float


func _enter_tree():
	add_to_group("note_manager")

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	for spawner in spawners:
		spawner.mouse_filter = MOUSE_FILTER_IGNORE

func _process(_delta):
	var curr_beat := _get_curr_beat()
	while next_note_beat < curr_beat + lookahead_beats:
		for spawner in spawners:
			var note: Note = NOTE_SCENE.instantiate()
			note.beat = next_note_beat
			#song_beat = next_note_beat
			note.conductor = conductor
			note.movement_direction = spawner.movement_direction
			note.target_position = spawner.offset
			note.flip_h = spawner.flip_h
			note.update_beat(-100)
			spawner.add_child(note)
			_all_notes.append(note)
		next_note_beat += 1.0
	_all_notes.sort_custom(func(a, b): return a.beat < b.beat)
	for note in _all_notes:
		note.update_beat(curr_beat)
	_miss_old_notes()

# =========================================================
# 🔑 ОСНОВНОЙ МЕТОД: РЕЗОЛВ РИТМА (stateless)
# =========================================================
func resolve_hit(spawner_index: int = 0) -> Enums.HitType:
	if spawner_index < 0 or spawner_index >= spawners.size():
		return Enums.HitType.MISS_LATE
	
	var curr_beat := _get_curr_beat()
	var spawner := spawners[spawner_index]
	var notes_in_spawner: Array[Note] = _all_notes.filter(func(n): return n.get_parent() == spawner)
	
	var closest_note: Note = null
	var closest_delta := INF
	# 1️⃣ Найти ближайшую ноту в указанном спавнере
	for note in notes_in_spawner:
		#print("current beat: " + str(curr_beat) + ", note beat" + str(note.beat))
		#print("current beat: " + str(curr_beat) + ", conductor beat" + str(conductor.get_current_beat()))
		#print((curr_beat - song_beat) + lookahead_beats)
		#print(curr_beat - note.beat)
		
		var delta : float = (curr_beat - note.beat) * conductor.get_beat_duration()
		if abs(delta) <= HIT_MARGIN_MISS and abs(delta) < abs(closest_delta):
			closest_delta = delta
			closest_note = note
	
	if closest_note == null:
		return Enums.HitType.MISS_LATE
	
	# 2️⃣ Определить hit_type
	var hit_type: Enums.HitType
	if abs(closest_delta) <= HIT_MARGIN_PERFECT:
		hit_type = Enums.HitType.PERFECT
	elif abs(closest_delta) <= HIT_MARGIN_GOOD:
		hit_type = Enums.HitType.GOOD_EARLY if closest_delta < 0 else Enums.HitType.GOOD_LATE
	else:
		hit_type = Enums.HitType.MISS_EARLY if closest_delta < 0 else Enums.HitType.MISS_LATE
	
	# 3️⃣ Применить результат только к этой ноте
	if hit_type == Enums.HitType.PERFECT:
		closest_note.hit_perfect()
	elif hit_type in [Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE]:
		closest_note.hit_good()
	else:
		closest_note.miss()
	
	# 4️⃣ Удалить только эту ноту
	_all_notes.erase(closest_note)
	
	# 5️⃣ Один сигнал — один результат
	note_hit.emit(closest_note.beat, hit_type, closest_delta)
	return hit_type

# =========================================================
func _miss_old_notes():
	while not _all_notes.is_empty():
		var note := _all_notes[0]
		if _get_note_delta(note) > HIT_MARGIN_GOOD:
			note._play_fade(Color.WHITE, 0.2)
			_all_notes.remove_at(0)
		else:
			break

func _get_note_delta(note: Note) -> float:
	return (_get_curr_beat() - note.beat) * conductor.get_beat_duration()

func _get_curr_beat() -> float:
	var beat := (
		conductor.get_current_beat()
		if time_type == Enums.TimeType.FILTERED
		else conductor.get_current_beat_raw()
	)
	beat -= GlobalSettings.input_latency_ms / 1000.0 / conductor.get_beat_duration()
	return beat
