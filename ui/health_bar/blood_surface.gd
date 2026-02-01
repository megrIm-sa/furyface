# res://scripts/ui/blood_surface.gd
class_name BloodSurface
extends ColorRect

@export var bus_name := "Music"
@export var buffer_size := 256
@export var smoothing := 0.2
@export var wave_amplitude := 12.0  # Высота волны в пикселях

var capture: AudioEffectCapture
var waveform := PackedFloat32Array()
var smooth := PackedFloat32Array()

var image: Image
var texture: ImageTexture

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Находим AudioEffectCapture на шине Music
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		push_warning("BloodSurface: Audio bus '%s' not found!" % bus_name)
		return
	
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectCapture:
			capture = fx
			break
	
	if not capture:
		push_warning("BloodSurface: AudioEffectCapture not found on bus '%s'!" % bus_name)
		return

	# Создаем буферы
	waveform.resize(buffer_size)
	smooth.resize(buffer_size)
	smooth.fill(0.0)

	# Создаем 1D текстуру для осциллограммы
	image = Image.create(buffer_size, 1, false, Image.FORMAT_RF)
	texture = ImageTexture.create_from_image(image)

	# Передаем в шейдер
	var mat = material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("waveform_tex", texture)
		mat.set_shader_parameter("amplitude", wave_amplitude)

func _process(_delta):
	if not capture:
		return
	
	# Проверяем доступные кадры
	if capture.get_frames_available() < buffer_size:
		return

	var frames := capture.get_buffer(buffer_size)

	# Читаем семплы (левый канал)
	for i in buffer_size:
		waveform[i] = frames[i].x

	# Сглаживание (spatial smoothing)
	for i in buffer_size:
		var prev := smooth[i - 1] if i > 0 else waveform[i]
		smooth[i] = lerp(prev, waveform[i], smoothing)

	# Записываем в текстуру
	for x in buffer_size:
		var v := smooth[x] * 0.5 + 0.5  # [-1..1] → [0..1]
		v = clamp(v, 0.0, 1.0)
		image.set_pixel(x, 0, Color(v, 0, 0))

	texture.update(image)

func set_wave_amplitude(value: float):
	"""Устанавливает амплитуду волны"""
	wave_amplitude = value
	var mat = material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("amplitude", wave_amplitude)
