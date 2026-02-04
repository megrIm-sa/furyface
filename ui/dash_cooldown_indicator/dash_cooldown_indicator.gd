class_name DashCooldownIndicator
extends ProgressBar

signal cooldown_finished()

@export_group("Dependencies")
@export var dash_component: DashComponent

@export_group("Settings")
@export var auto_hide_when_ready: bool = true
@export var smooth_transition: bool = true
@export var smooth_speed: float = 10.0

var current_cooldown: float = 0.0
var max_cooldown: float = 1.0

func _ready() -> void:
	# Настройка визуала
	min_value = 0.0
	max_value = 100.0
	value = 100.0
	show_percentage = false
	
	await get_tree().process_frame
	
	if not dash_component:
		push_error("DashCooldownIndicator: dash_component not assigned!")
		return
	
	# Подключаемся к сигналам
	dash_component.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
	dash_component.dash_started.connect(_on_dash_started)
	
	# Начальное состояние
	if auto_hide_when_ready:
		visible = false

func _process(delta: float) -> void:
	if not dash_component:
		return
	
	# Обновляем прогресс
	if dash_component.cooldown_timer > 0.0:
		if not visible:
			visible = true
		
		_update_progress(delta)
	else:
		# Кулдаун закончен
		_on_cooldown_ready(delta)

func _update_progress(delta: float) -> void:
	"""Обновляет прогресс индикатора"""
	var progress = dash_component.get_cooldown_percent() * 100.0
	
	if smooth_transition:
		value = lerp(value, progress, smooth_speed * delta)
	else:
		value = progress

func _on_cooldown_ready(delta: float) -> void:
	"""Вызывается когда кулдаун готов"""
	if smooth_transition:
		value = lerp(value, 100.0, smooth_speed * delta)
		
		# Скрываем когда достигли 100%
		if value >= 99.0 and auto_hide_when_ready:
			visible = false
	else:
		value = 100.0
		if auto_hide_when_ready:
			visible = false

func _on_dash_cooldown_changed(current: float, maximum: float) -> void:
	"""Вызывается при изменении кулдауна"""
	current_cooldown = current
	max_cooldown = maximum
	
	if current > 0.0:
		# Кулдаун начался
		value = 0.0
		if auto_hide_when_ready:
			visible = true
	else:
		# Кулдаун закончен
		cooldown_finished.emit()

func _on_dash_started(direction: Vector2, hit_type: Enums.HitType) -> void:
	"""Вызывается при начале dash"""
	# Визуальный эффект в зависимости от типа
	match hit_type:
		Enums.HitType.PERFECT:
			_play_perfect_effect()
		Enums.HitType.MISS_EARLY, Enums.HitType.MISS_LATE:
			_play_miss_effect()

func _play_perfect_effect() -> void:
	"""Визуальный эффект для perfect dash"""
	# TODO: Добавить анимацию или вспышку
	pass

func _play_miss_effect() -> void:
	"""Визуальный эффект для промаха"""
	# TODO: Добавить эффект ошибки
	pass
