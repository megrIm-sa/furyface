class_name ComboBar
extends TextureRect

signal combo_percent_changed(percent: float)

@export_group("Transition")
@export var smooth_transition: bool = true
@export var transition_speed: float = 0.2

@export_group("Audio Wave")
@export var use_audio_wave: bool = false
@export var bus_name := "Music"
@export var buffer_size := 256
@export var smoothing := 0.2
@export var wave_amplitude := 8.0

@export_group("Mask Icon")
@export var mask_icon_container: TextureRect  # Контейнер для иконки маски

@export_group("Components")
@export var combo_component: ComboComponent  # Ссылка на ComboComponent
@export var mask_ability_manager: MaskAbilityManager  # Для иконки маски и способности

var current_combo_percent: float = 0.0

var capture: AudioEffectCapture
var waveform := PackedFloat32Array()
var smooth_wave := PackedFloat32Array()
var image: Image
var texture_wave: ImageTexture

var shader_material: ShaderMaterial
var time_accumulated: float = 0.0

func _ready() -> void:
	shader_material = material as ShaderMaterial
	
	await get_tree().process_frame
	
	if use_audio_wave:
		_setup_audio_capture()
	
	if not combo_component:
		push_error("ComboBar: ComboComponent not found! Please assign it in Inspector.")
		return
	
	# Подключаемся к ComboComponent
	combo_component.combo_changed.connect(_on_combo_changed)
	
	# Подключаемся к MaskAbilityManager (если есть)
	if mask_ability_manager:
		mask_ability_manager.ability_activated.connect(_on_ability_activated)
		mask_ability_manager.ability_deactivated.connect(_on_ability_deactivated)
		mask_ability_manager.mask_changed.connect(_on_mask_changed)
		
		# Устанавливаем начальную иконку маски
		if mask_ability_manager.current_mask:
			_on_mask_changed(mask_ability_manager.current_mask)
	
	# Устанавливаем начальное значение комбо
	_on_combo_changed(combo_component.current_combo, combo_component.max_combo)

func _setup_audio_capture() -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		push_warning("ComboBar: Audio bus '%s' not found!" % bus_name)
		return
	
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectCapture:
			capture = fx
			break
	
	if not capture:
		push_warning("ComboBar: AudioEffectCapture not found on bus '%s'!" % bus_name)
		return
	
	waveform.resize(buffer_size)
	smooth_wave.resize(buffer_size)
	smooth_wave.fill(0.0)
	
	image = Image.create(buffer_size, 1, false, Image.FORMAT_RF)
	texture_wave = ImageTexture.create_from_image(image)
	
	if shader_material:
		shader_material.set_shader_parameter("waveform_tex", texture_wave)
		shader_material.set_shader_parameter("amplitude", wave_amplitude)

func _process(delta: float) -> void:
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

func _on_combo_changed(current: float, maximum: float) -> void:
	if maximum <= 0:
		_set_combo_percent(0.0)
		return
	
	var new_percent = current / maximum
	_set_combo_percent(new_percent)

func _set_combo_percent(percent: float) -> void:
	percent = clamp(percent, 0.0, 1.0)
	
	if not shader_material:
		return
	
	if smooth_transition:
		var tween = create_tween()
		tween.tween_method(
			func(p): shader_material.set_shader_parameter("health_percent", p),
			current_combo_percent,
			percent,
			transition_speed
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.finished.connect(func(): 
			current_combo_percent = percent
			combo_percent_changed.emit(percent)
		)
	else:
		shader_material.set_shader_parameter("health_percent", percent)
		current_combo_percent = percent
		combo_percent_changed.emit(percent)

func _on_ability_activated() -> void:
	"""Вызывается когда способность активируется"""
	if shader_material:
		shader_material.set_shader_parameter("ability_active", true)
	
	# Анимация пульсации иконки
	if mask_icon_container:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(mask_icon_container, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(mask_icon_container, "scale", Vector2(1.0, 1.0), 0.5)

func _on_ability_deactivated() -> void:
	"""Вызывается когда способность деактивируется"""
	if shader_material:
		shader_material.set_shader_parameter("ability_active", false)
	
	# Останавливаем анимацию иконки
	if mask_icon_container:
		var tween = create_tween()
		tween.tween_property(mask_icon_container, "scale", Vector2(1.0, 1.0), 0.2)

func _on_mask_changed(mask: BaseMask) -> void:
	"""Вызывается когда меняется маска"""
	if mask_icon_container and mask.mask_icon:
		mask_icon_container.texture = mask.mask_icon
	
	# Обновляем цвет свечения в шейдере
	if shader_material and mask:
		shader_material.set_shader_parameter("ability_glow_color", mask.activation_color)

## Устанавливает процент комбо напрямую (для внешнего использования)
func set_combo_percent(percent: float) -> void:
	_set_combo_percent(percent)

## Обновляет визуал без анимации
func set_combo_immediate(percent: float) -> void:
	percent = clamp(percent, 0.0, 1.0)
	if shader_material:
		shader_material.set_shader_parameter("health_percent", percent)
		current_combo_percent = percent
