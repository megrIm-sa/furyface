# dash_cooldown_indicator.gd
extends ProgressBar

@onready var player: Player = null

var current_max_cooldown: float = 0.0

func _ready():
	# Ждём один кадр чтобы player был инициализирован
	await get_tree().process_frame
	
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		player.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
	else:
		push_warning("DashCooldownIndicator: Player not found!")
	
	# Настройка визуала
	min_value = 0.0
	max_value = 100.0  # Работаем в процентах
	value = 100.0
	show_percentage = false

func _process(_delta):
	if not player:
		return
	
	if player.dash_cooldown_timer > 0.0 and current_max_cooldown > 0.0:
		visible = true
		
		# Вычисляем прогресс: от 0% (начало) до 100% (конец)
		var time_elapsed = current_max_cooldown - player.dash_cooldown_timer
		var progress_percent = (time_elapsed / current_max_cooldown) * 100.0
		value = clamp(progress_percent, 0.0, 100.0)
		
	else:
		# Кулдаун закончен
		visible = false
		value = 100.0


func _on_dash_cooldown_changed(current: float, maximum: float):
	# Сохраняем максимальный кулдаун для текущего dash
	current_max_cooldown = maximum
	
	# Сбрасываем прогресс на 0%
	value = 0.0
	
	# Показываем индикатор
	visible = true
