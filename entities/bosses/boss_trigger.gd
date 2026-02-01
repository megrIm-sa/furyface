# res://scripts/triggers/boss_trigger.gd
class_name BossTrigger
extends Area2D

@export var boss: FearMaskBoss  # Ссылка на босса
@export var trigger_once: bool = true  # Срабатывает только один раз

var has_triggered: bool = false
var boss_health_bar: BossHealthBar = null

func _ready():
	# Подключаем сигналы
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Находим BossHealthBar
	_find_boss_health_bar()
	
	print("[BossTrigger] Boss trigger ready")

func _find_boss_health_bar():
	"""Находит BossHealthBar в дереве сцен"""
	boss_health_bar = boss.find_child("BossHealthBar")
	
	# Альтернативный поиск через путь
	if not boss_health_bar:
		boss_health_bar = get_node_or_null("/root/Main/UILayer/BossHealthBar")
	
	if not boss_health_bar:
		push_warning("[BossTrigger] BossHealthBar not found!")

func _on_body_entered(body: Node2D):
	"""Вызывается когда что-то входит в триггер"""
	if has_triggered and trigger_once:
		return
	
	if not body.is_in_group("player"):
		return
	
	if not boss:
		push_warning("[BossTrigger] No boss assigned to trigger!")
		return
	
	if not boss_health_bar:
		push_warning("[BossTrigger] BossHealthBar not found!")
		return
	
	# Показываем health bar босса
	boss_health_bar.show_boss_health(boss)
	has_triggered = true
	
	print("[BossTrigger] Player entered, showing boss health bar")

func _on_body_exited(body: Node2D):
	"""Опционально: скрывает health bar когда игрок уходит"""
	# Закомментируйте если не хотите скрывать при выходе
	# if not body.is_in_group("player"):
	# 	return
	# 
	# if boss_health_bar:
	# 	boss_health_bar.hide_boss_health()
	pass
