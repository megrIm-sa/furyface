class_name DashCooldownIndicator
extends ProgressBar

signal cooldown_started()
signal cooldown_finished()

@export_group("Dependencies")
@export var dash_component: DashComponent

@export_group("Settings")
@export var auto_hide_when_ready: bool = true
@export var smooth_update: bool = true

var current_max_cooldown: float = 0.0
var target_value: float = 100.0

func _ready() -> void:
	# Настройка визуала
	min_value = 0.0
	max_value = 100.0
	value = 100.0
	show_percentage = false
	
	await get_tree().process_frame
	
	if not dash_component:
		dash_component = _find_dash_component()
	
	if not dash_component:
		push_error("DashCooldownIndicator: dash_component not assigned!")
		return
	
	# Подключаемся к сигналам DashComponent
	dash_component.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
	dash_component.dash_started.connect(_on_dash_started)
	
	# Устанавливаем начальное состояние
	if auto_hide_when_ready:
		visible = false

func _process(delta: float) -> void:
	if not dash_component:
		return
	
	# Обновляем прогресс в реальном времени
	if dash_component.is_on_cooldown():
		if not visible:
			visible = true
		
		_update_cooldown_progress()
	else:
		# Кулдаун закончен
		if auto_hide_when_ready and visible:
			visible = false
		
		if smooth_update:
			value = lerp(value, 100.0, delta * 10.0)
		else:
			value = 100.0

func _update_cooldown_progress() -> void:
	"""Обновляет прогресс кулдауна"""
	if current_max_cooldown <= 0.0:
		return
	
	var current_cooldown = dash_component.get_cooldown_remaining()
	var time_elapsed = current_max_cooldown - current_cooldown
	var progress_percent = (time_elapsed / current_max_cooldown) * 100.0
	
	target_value = clamp(progress_percent, 0.0, 100.0)
	
	if smooth_update:
		value = lerp(value, target_value, 0.2)
	else:
		value = target_value

func _on_dash_cooldown_changed(current: float, maximum: float) -> void:
	"""Вызывается при изменении кулдауна"""
	current_max_cooldown = maximum
	
	if current > 0.0:
		# Кулдаун активен
		value = 0.0
		target_value = 0.0
		
		if auto_hide_when_ready:
			visible = true
		
		cooldown_started.emit()
	else:
		# Кулдаун закончен
		value = 100.0
		target_value = 100.0
		
		if auto_hide_when_ready:
			visible = false
		
		cooldown_finished.emit()

func _on_dash_started() -> void:
	"""Вызывается при начале dash"""
	# Можно добавить визуальный эффект (вспышка, анимация)
	pass

func _find_dash_component() -> DashComponent:
	"""Ищет DashComponent в родительской иерархии (fallback)"""
	var parent = get_parent()
	while parent:
		# Проверяем, есть ли DashComponent у родителя
		if parent.has_node("DashComponent"):
			return parent.get_node("DashComponent") as DashComponent
		
		# Ищем CanvasLayer -> Player
		if parent is CanvasLayer:
			parent = parent.get_parent()
			if parent and parent.has_node("DashComponent"):
				return parent.get_node("DashComponent") as DashComponent
		
		parent = parent.get_parent()
	
	return null

## Устанавливает прогресс напрямую (для внешнего использования)
func set_progress(percent: float) -> void:
	value = clamp(percent, 0.0, 100.0)
	target_value = value

## Принудительно показывает индикатор
func force_show() -> void:
	visible = true

## Принудительно скрывает индикатор
func force_hide() -> void:
	visible = false
