extends ColorRect

@export var bus_name := "Music"
@export var buffer_size := 256
@export var smoothing := 0.2

var capture: AudioEffectCapture
var waveform := PackedFloat32Array()
var smooth := PackedFloat32Array()

var image: Image
var texture: ImageTexture

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- Audio capture ---
	var bus := AudioServer.get_bus_index(bus_name)
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectCapture:
			capture = fx
			break

	# --- Buffers ---
	waveform.resize(buffer_size)
	smooth.resize(buffer_size)

	# --- 1D texture ---
	image = Image.create(
		buffer_size,
		1,
		false,
		Image.FORMAT_RF
	)

	texture = ImageTexture.create_from_image(image)

	(material as ShaderMaterial).set_shader_parameter(
		"waveform_tex",
		texture
	)

func _process(_delta):
	if not capture:
		return
	if capture.get_frames_available() < buffer_size:
		return

	var frames := capture.get_buffer(buffer_size)

	# --- Read samples ---
	for i in buffer_size:
		waveform[i] = frames[i].x

	# --- Spatial smoothing ---
	for i in buffer_size:
		var prev := smooth[i] if i > 0 else waveform[i]
		smooth[i] = lerp(prev, waveform[i], smoothing)

	# --- Write waveform to texture ---
	for x in buffer_size:
		var v := smooth[x] * 0.5 + 0.5 # [-1..1] → [0..1]
		v = clamp(v, 0.0, 1.0)
		image.set_pixel(x, 0, Color(v, 0, 0))

	texture.update(image)
