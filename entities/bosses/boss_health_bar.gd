# res://scripts/ui/boss_health_bar.gd
class_name BossHealthBar
extends Control

@export var boss_name_label: Label
@export var health_bar: ProgressBar
@export var health_text: Label  # Опционально для отображения чисел

var boss: FearMaskBoss = null
var is_visible_bar: bool = false

func _ready():
	# Скрываем по умолчанию
	hide()

func show_boss_health(boss_node: FearMaskBoss):
	print("Показывает health bar и подключается к боссу")
	"""Показывает health bar и подключается к боссу"""
	if boss == boss_node:
		return
	
	# Отключаемся от предыдущего босса
	if boss:
		_disconnect_from_boss()
	
	boss = boss_node
	
	if not boss:
		hide()
		return
	
	# Подключаемся к сигналам
	boss.health_changed.connect(_on_boss_health_changed)
	boss.died.connect(_on_boss_died)
	
	# Устанавливаем начальные значения
	if boss_name_label:
		boss_name_label.text = boss.boss_name
	
	if health_bar:
		health_bar.max_value = boss.max_health
		health_bar.value = boss.current_health
	
	_update_health_text(boss.current_health, boss.max_health)
	
	# Показываем
	show()
	is_visible_bar = true
	print("[BossHealthBar] Showing health bar for: %s" % boss.boss_name)

func hide_boss_health():
	"""Скрывает health bar"""
	_disconnect_from_boss()
	hide()
	is_visible_bar = false

func _disconnect_from_boss():
	"""Отключается от сигналов босса"""
	if boss:
		if boss.health_changed.is_connected(_on_boss_health_changed):
			boss.health_changed.disconnect(_on_boss_health_changed)
		if boss.died.is_connected(_on_boss_died):
			boss.died.disconnect(_on_boss_died)
		boss = null

func _on_boss_health_changed(current: float, maximum: float):
	"""Обновляет health bar при изменении здоровья"""
	if health_bar:
		health_bar.value = current
	
	_update_health_text(current, maximum)

func _update_health_text(current: float, maximum: float):
	"""Обновляет текст с числами (опционально)"""
	if health_text:
		health_text.text = "%.0f / %.0f" % [current, maximum]

func _on_boss_died():
	"""Скрывает health bar когда босс умирает"""
	print("[BossHealthBar] Boss died, hiding health bar")
	
	# Плавное исчезновение
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	
	hide_boss_health()
	modulate.a = 1.0  # Восстанавливаем для следующего использования
