# res://scripts/ui/combo_bar.gd
class_name ComboBar
extends TextureRect

@export var smooth_transition: bool = true
@export var transition_speed: float = 0.2

@export var use_audio_wave: bool = false
@export var bus_name := "Music"
@export var buffer_size := 256
@export var smoothing := 0.2
@export var wave_amplitude := 8.0

@export_group("Mask Icon")
@export var mask_icon_container: TextureRect  # Контейнер для иконки маски

var player: Player = null
var current_combo_percent: float = 0.0

var capture: AudioEffectCapture
var waveform := PackedFloat32Array()
var smooth_wave := PackedFloat32Array()
var image: Image
var texture_wave: ImageTexture

var shader_material: ShaderMaterial
var time_accumulated: float = 0.0

func _ready():
	await get_tree().process_frame
	
	shader_material = material as ShaderMaterial
	
	if use_audio_wave:
		_setup_audio_capture()
	
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_warning("ComboBar: Player not found!")
		return
	
	if not player.mask_ability:
		push_warning("ComboBar: Player has no MaskAbilityManager!")
		return
	
	# Подключаемся к сигналам
	player.mask_ability.combo_changed.connect(_on_combo_changed)
	player.mask_ability.ability_activated.connect(_on_ability_activated)
	player.mask_ability.ability_deactivated.connect(_on_ability_deactivated)
	player.mask_ability.mask_changed.connect(_on_mask_changed)
	
	# Устанавливаем начальные значения
	var mask_ability = player.mask_ability
	_on_combo_changed(mask_ability.current_combo, mask_ability.max_combo)
	
	# Устанавливаем иконку маски
	if mask_ability.current_mask:
		_on_mask_changed(mask_ability.current_mask)

func _setup_audio_capture():
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectCapture:
			capture = fx
			break
	
	if not capture:
		return
	
	waveform.resize(buffer_size)
	smooth_wave.resize(buffer_size)
	smooth_wave.fill(0.0)
	
	image = Image.create(buffer_size, 1, false, Image.FORMAT_RF)
	texture_wave = ImageTexture.create_from_image(image)
	
	if shader_material:
		shader_material.set_shader_parameter("waveform_tex", texture_wave)
		shader_material.set_shader_parameter("amplitude", wave_amplitude)

func _process(delta):
	# Обновляем time для анимации в шейдере
	time_accumulated += delta
	if shader_material:
		shader_material.set_shader_parameter("time", time_accumulated)
	
	# Обновляем аудио волну
	if not use_audio_wave or not capture:
		return
	
	if capture.get_frames_available() < buffer_size:
		return
	
	var frames := capture.get_buffer(buffer_size)
	
	for i in buffer_size:
		waveform[i] = frames[i].x
	
	for i in buffer_size:
		var prev := smooth_wave[i - 1] if i > 0 else waveform[i]
		smooth_wave[i] = lerp(prev, waveform[i], smoothing)
	
	for x in buffer_size:
		var v := smooth_wave[x] * 0.5 + 0.5
		v = clamp(v, 0.0, 1.0)
		image.set_pixel(x, 0, Color(v, 0, 0))
	
	texture_wave.update(image)

func _on_combo_changed(current: float, maximum: float):
	if maximum <= 0:
		_set_combo_percent(0.0)
		return
	
	var new_percent = current / maximum
	_set_combo_percent(new_percent)

func _set_combo_percent(percent: float):
	percent = clamp(percent, 0.0, 1.0)
	
	if shader_material:
		if smooth_transition:
			var tween = create_tween()
			tween.tween_method(
				func(p): shader_material.set_shader_parameter("health_percent", p),
				current_combo_percent,
				percent,
				transition_speed
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tween.finished.connect(func(): current_combo_percent = percent)
		else:
			shader_material.set_shader_parameter("health_percent", percent)
			current_combo_percent = percent

func _on_ability_activated():
	"""Вызывается когда способность активируется"""
	print("[ComboBar] Ability ACTIVATED!")
	if shader_material:
		shader_material.set_shader_parameter("ability_active", true)
	
	# Анимация пульсации иконки
	if mask_icon_container:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(mask_icon_container, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(mask_icon_container, "scale", Vector2(1.0, 1.0), 0.5)

func _on_ability_deactivated():
	"""Вызывается когда способность деактивируется"""
	print("[ComboBar] Ability DEACTIVATED!")
	if shader_material:
		shader_material.set_shader_parameter("ability_active", false)
	
	# Останавливаем анимацию иконки
	if mask_icon_container:
		var tween = create_tween()
		tween.tween_property(mask_icon_container, "scale", Vector2(1.0, 1.0), 0.2)

func _on_mask_changed(mask: BaseMask):
	"""Вызывается когда меняется маска"""
	if mask_icon_container and mask.mask_icon:
		mask_icon_container.texture = mask.mask_icon
		print("[ComboBar] Mask icon updated: %s" % mask.mask_name)
	
	# Обновляем цвет свечения в шейдере
	if shader_material and mask:
		shader_material.set_shader_parameter("ability_glow_color", mask.activation_color)
