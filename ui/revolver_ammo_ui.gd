# res://scripts/ui/revolver_ammo_ui.gd
class_name RevolverAmmoUI
extends ProgressBar

@onready var weapon_manager: WeaponManager = null
var revolvers: DualRevolvers = null

var max_total_ammo: int = 12  # 6 + 6
var current_total_ammo: int = 12

var is_reloading: bool = false
var reload_progress: float = 0.0

func _ready():
	await get_tree().process_frame
	
	# Находим WeaponManager
	var player = get_tree().get_first_node_in_group("player")
	if player:
		weapon_manager = player.get_node_or_null("WeaponManager")
	
	if not weapon_manager:
		push_warning("RevolverAmmoUI: WeaponManager not found!")
		return
	
	# Подключаемся к сигналам WeaponManager
	weapon_manager.weapon_switched.connect(_on_weapon_switched)
	
	# Проверяем текущее оружие
	_check_current_weapon()
	
	# Настройка визуала
	min_value = 0.0
	show_percentage = false

func _check_current_weapon():
	if not weapon_manager:
		return
	
	# Проверяем, револьверы ли сейчас активны
	if weapon_manager.current_weapon and weapon_manager.current_weapon is DualRevolvers:
		_connect_to_revolvers(weapon_manager.current_weapon as DualRevolvers)
		visible = true
	else:
		visible = false

func _on_weapon_switched(weapon_type: Enums.WeaponType):
	if weapon_type == Enums.WeaponType.REVOLVERS:
		var weapon = weapon_manager.get_weapon(Enums.WeaponType.REVOLVERS)
		if weapon and weapon is DualRevolvers:
			_connect_to_revolvers(weapon as DualRevolvers)
			visible = true
	else:
		# Другое оружие, скрываем UI
		_disconnect_from_revolvers()
		visible = false

func _connect_to_revolvers(revolver_weapon: DualRevolvers):
	# Отключаемся от предыдущих револьверов
	_disconnect_from_revolvers()
	
	revolvers = revolver_weapon
	
	# Подключаемся к сигналам
	revolvers.ammo_changed.connect(_on_ammo_changed)
	revolvers.reload_started.connect(_on_reload_started)
	revolvers.reload_progress_updated.connect(_on_reload_progress_updated)
	
	# Получаем текущее состояние
	var ammo_info = revolvers.get_ammo_info()
	max_total_ammo = ammo_info["max_per_gun"] * 2
	current_total_ammo = ammo_info["left"] + ammo_info["right"]
	
	max_value = max_total_ammo
	value = current_total_ammo
	
	is_reloading = ammo_info["is_reloading"]

func _disconnect_from_revolvers():
	if revolvers:
		if revolvers.ammo_changed.is_connected(_on_ammo_changed):
			revolvers.ammo_changed.disconnect(_on_ammo_changed)
		if revolvers.reload_started.is_connected(_on_reload_started):
			revolvers.reload_started.disconnect(_on_reload_started)
		if revolvers.reload_progress_updated.is_connected(_on_reload_progress_updated):
			revolvers.reload_progress_updated.disconnect(_on_reload_progress_updated)
		revolvers = null

func _process(_delta):
	if not revolvers:
		return
	
	if is_reloading:
		# Во время перезарядки показываем прогресс
		value = reload_progress * max_total_ammo
	else:
		# Показываем текущие патроны
		value = current_total_ammo

func _on_ammo_changed(left: int, right: int, max_per_gun: int):
	current_total_ammo = left + right
	max_total_ammo = max_per_gun * 2
	max_value = max_total_ammo
	
	if not is_reloading:
		value = current_total_ammo

func _on_reload_started(reload_duration: float):
	modulate = Color.FIREBRICK
	is_reloading = true
	reload_progress = 0.0
	value = 0.0

func _on_reload_progress_updated(progress: float):
	reload_progress = progress
	
	if progress >= 1.0:
		modulate = Color.WHITE
		is_reloading = false
		value = max_total_ammo
