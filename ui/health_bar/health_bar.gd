class_name HealthBar
extends TextureRect

signal health_percent_changed(percent: float)

@export_group("Transition")
@export var smooth_transition: bool = true
@export var transition_speed: float = 0.3

@export_group("Audio Wave")
@export var use_audio_wave: bool = true
@export var bus_name := "Music"
@export var buffer_size := 256
@export var smoothing := 0.2
@export var wave_amplitude := 12.0

@export_group("Components")
@export var health_component: HealthComponent  # Ссылка на HealthComponent

var current_health_percent: float = 1.0

var capture: AudioEffectCapture
var waveform := PackedFloat32Array()
var smooth_wave := PackedFloat32Array()
var image: Image
var _texture: ImageTexture
var shader_material: ShaderMaterial

func _ready() -> void:
	shader_material = material as ShaderMaterial
	
	await get_tree().process_frame
	
	if use_audio_wave:
		_setup_audio_capture()

	if not health_component:
		push_error("HealthBar: HealthComponent not found! Please assign it in Inspector.")
		return
	
	# Подключаемся к сигналам
	health_component.health_changed.connect(_on_health_changed)
	
	# Устанавливаем начальное значение
	_on_health_changed(health_component.current_health, health_component.max_health)

func _setup_audio_capture() -> void:
	"""Настройка захвата аудио"""
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		push_warning("HealthBar: Audio bus '%s' not found!" % bus_name)
		return
	
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectCapture:
			capture = fx
			break
	
	if not capture:
		push_warning("HealthBar: AudioEffectCapture not found on bus '%s'!" % bus_name)
		return
	
	waveform.resize(buffer_size)
	smooth_wave.resize(buffer_size)
	smooth_wave.fill(0.0)
	
	image = Image.create(buffer_size, 1, false, Image.FORMAT_RF)
	_texture = ImageTexture.create_from_image(image)
	
	if shader_material:
		shader_material.set_shader_parameter("waveform_tex", _texture)
		shader_material.set_shader_parameter("amplitude", wave_amplitude)

func _process(_delta: float) -> void:
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
	
	_texture.update(image)

func _on_health_changed(current: float, maximum: float) -> void:
	if maximum <= 0:
		_set_health_percent(0.0)
		return
	
	var new_percent = current / maximum
	_set_health_percent(new_percent)

func _set_health_percent(percent: float) -> void:
	percent = clamp(percent, 0.0, 1.0)
	
	if not shader_material:
		return
	
	if smooth_transition:
		var tween = create_tween()
		tween.tween_method(
			func(p): shader_material.set_shader_parameter("health_percent", p),
			current_health_percent,
			percent,
			transition_speed
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.finished.connect(func(): 
			current_health_percent = percent
			health_percent_changed.emit(percent)
		)
	else:
		shader_material.set_shader_parameter("health_percent", percent)
		current_health_percent = percent
		health_percent_changed.emit(percent)

## Устанавливает процент здоровья напрямую (для внешнего использования)
func set_health_percent(percent: float) -> void:
	_set_health_percent(percent)

## Обновляет визуал без анимации
func set_health_immediate(percent: float) -> void:
	percent = clamp(percent, 0.0, 1.0)
	if shader_material:
		shader_material.set_shader_parameter("health_percent", percent)
		current_health_percent = percent
