class_name BeatSyncComponent
extends Node

signal beat_occurred(beat_number: int)
signal beat_progress_updated(progress: float)

var conductor: Conductor
var current_beat: float = 0.0
var last_beat_int: int = -1

func _ready() -> void:
	add_to_group("beat_sync")
	
	conductor = get_tree().get_first_node_in_group("conductor")
	
	if not conductor:
		push_warning("BeatSyncComponent: conductor not found in group 'conductor'!")

func _process(_delta: float) -> void:
	if not conductor:
		return
	
	current_beat = conductor.get_current_beat()
	var beat_int = int(floor(current_beat))
	
	if beat_int != last_beat_int:
		beat_occurred.emit(beat_int)
		last_beat_int = beat_int
	
	var progress = get_beat_progress()
	beat_progress_updated.emit(progress)

## Возвращает прогресс текущего бита (0.0 - 1.0)
func get_beat_progress() -> float:
	return current_beat - floor(current_beat)

## Проверяет, близко ли к биту
func is_near_beat(threshold: float = 0.1) -> bool:
	var progress = get_beat_progress()
	return progress < threshold or progress > (1.0 - threshold)

## Ожидает следующего бита
func wait_for_next_beat() -> void:
	var current_beat_int = int(floor(current_beat))
	while int(floor(current_beat)) == current_beat_int:
		await get_tree().process_frame
