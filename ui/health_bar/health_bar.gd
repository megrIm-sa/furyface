# res://scripts/ui/health_bar.gd (упрощенная версия)
class_name HealthBar
extends TextureRect

@export var smooth_transition: bool = true
@export var transition_speed: float = 0.3

# Для захвата аудио
@export var bus_name := "Music"
@export var buffer_size := 256
@export var smoothing := 0.2
@export var wave_amplitude := 12.0

var player: Player = null
var current_health_percent: float = 1.0

var capture: AudioEffectCapture
var waveform := PackedFloat32Array()
var smooth := PackedFloat32Array()
var image: Image
var _texture: ImageTexture

func _ready():
	await get_tree().process_frame
	
	_setup_audio_capture()
	
	# Находим игрока
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_warning("HealthBar: Player not found!")
		return
	
	player.health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(player.current_health, player.max_health)

func _setup_audio_capture():
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
		push_warning("HealthBar: AudioEffectCapture not found!")
		return
	
	waveform.resize(buffer_size)
	smooth.resize(buffer_size)
	smooth.fill(0.0)
	
	image = Image.create(buffer_size, 1, false, Image.FORMAT_RF)
	_texture = ImageTexture.create_from_image(image)
	
	var mat = material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("waveform_tex", _texture)
		mat.set_shader_parameter("amplitude", wave_amplitude)

func _process(_delta):
	if not capture:
		return
	
	if capture.get_frames_available() < buffer_size:
		return
	
	var frames := capture.get_buffer(buffer_size)
	
	for i in buffer_size:
		waveform[i] = frames[i].x
	
	for i in buffer_size:
		var prev := smooth[i - 1] if i > 0 else waveform[i]
		smooth[i] = lerp(prev, waveform[i], smoothing)
	
	for x in buffer_size:
		var v := smooth[x] * 0.5 + 0.5
		v = clamp(v, 0.0, 1.0)
		image.set_pixel(x, 0, Color(v, 0, 0))
	
	_texture.update(image)

func _on_player_health_changed(current: float, maximum: float):
	if maximum <= 0:
		_set_health_percent(0.0)
		return
	
	var new_percent = current / maximum
	_set_health_percent(new_percent)

func _set_health_percent(percent: float):
	percent = clamp(percent, 0.0, 1.0)
	
	var mat = material as ShaderMaterial
	if mat:
		if smooth_transition:
			var tween = create_tween()
			tween.tween_method(
				func(p): mat.set_shader_parameter("health_percent", p),
				current_health_percent,
				percent,
				transition_speed
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.finished.connect(func(): current_health_percent = percent)
		else:
			mat.set_shader_parameter("health_percent", percent)
			current_health_percent = percent
