extends Node

const CONFIG_PATH    := "user://config/board.json"
const SETTINGS_PATH  := "user://config/settings.json"

func _ready() -> void:
	_ensure_dirs()

func _ensure_dirs() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive("config")
		dir.make_dir_recursive("sounds")
		dir.make_dir_recursive("images")

func load_board() -> Array[ButtonConfig]:
	if not FileAccess.file_exists(CONFIG_PATH):
		return []
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("ConfigManager: Cannot open %s" % CONFIG_PATH)
		return []
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.has("buttons"):
		return []
	var result: Array[ButtonConfig] = []
	for item in parsed["buttons"]:
		if item is Dictionary:
			result.append(_dict_to_config(item))
	return result

func save_board(buttons: Array[ButtonConfig]) -> void:
	_ensure_dirs()
	var data := {"version": 1, "buttons": []}
	for btn in buttons:
		data["buttons"].append(_config_to_dict(btn))
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ConfigManager: Cannot write to %s" % CONFIG_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

func save_settings(settings: Dictionary) -> void:
	_ensure_dirs()
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ConfigManager: cannot write settings")
		return
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()

func generate_id() -> String:
	return "%d_%d" % [randi(), Time.get_ticks_usec()]

## Load an audio stream from a res://, user://, or absolute path.
func load_audio_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if path.begins_with("res://"):
		return load(path) as AudioStream
	# For user:// or absolute paths, try ResourceLoader then fall back to manual WAV parsing.
	if not FileAccess.file_exists(path):
		return null
	return _parse_wav(path)

func _parse_wav(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	if f.get_buffer(4).get_string_from_ascii() != "RIFF":
		f.close(); return null
	f.get_32()  # chunk size
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		f.close(); return null
	# Skip chunks until we find "fmt "
	while not f.eof_reached():
		var chunk_id := f.get_buffer(4).get_string_from_ascii()
		var chunk_size := f.get_32()
		if chunk_id == "fmt ":
			break
		f.seek(f.get_position() + chunk_size)
	if f.eof_reached():
		f.close(); return null
	f.get_16()  # audio format (1 = PCM)
	var channels := f.get_16()
	var sample_rate := f.get_32()
	f.get_32()  # byte rate
	f.get_16()  # block align
	var bits_per_sample := f.get_16()
	# Skip to "data" chunk
	while not f.eof_reached():
		var chunk_id := f.get_buffer(4).get_string_from_ascii()
		var chunk_size := f.get_32()
		if chunk_id == "data":
			var data := f.get_buffer(chunk_size)
			f.close()
			var wav := AudioStreamWAV.new()
			wav.data = data
			wav.mix_rate = sample_rate
			wav.stereo = (channels == 2)
			wav.format = AudioStreamWAV.FORMAT_8_BITS if bits_per_sample == 8 else AudioStreamWAV.FORMAT_16_BITS
			return wav
		f.seek(f.get_position() + chunk_size)
	f.close()
	return null

## Load a Texture2D from a res://, user://, or absolute path.
func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if path.begins_with("res://"):
		return load(path) as Texture2D
	var abs_path := path
	if path.begins_with("user://"):
		abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path if path.begins_with("user://") else abs_path):
		return null
	var img := Image.load_from_file(abs_path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

## Copy a file into user://sounds/ and return the new user:// path.
func import_sound(src_path: String) -> String:
	_ensure_dirs()
	var filename := src_path.get_file()
	var dest := "user://sounds/" + filename
	_copy_file(src_path, dest)
	return dest

## Copy a file into user://images/ and return the new user:// path.
func import_image(src_path: String) -> String:
	_ensure_dirs()
	var filename := src_path.get_file()
	var dest := "user://images/" + filename
	_copy_file(src_path, dest)
	return dest

## Decode an AudioStreamWAV back to a mono float PCM array (for waveform display).
## Handles 8-bit and 16-bit, mono and stereo. Stereo is mixed down to mono.
func wav_to_pcm(stream: AudioStreamWAV) -> PackedFloat32Array:
	var bytes := stream.data
	var pcm := PackedFloat32Array()
	if bytes.is_empty():
		return pcm
	var is_stereo := stream.stereo
	match stream.format:
		AudioStreamWAV.FORMAT_8_BITS:
			var stride := 2 if is_stereo else 1
			@warning_ignore("integer_division")
			var n: int = bytes.size() / stride
			pcm.resize(n)
			for i in range(n):
				if is_stereo:
					var l := (float(bytes[i * 2])     - 128.0) / 128.0
					var r := (float(bytes[i * 2 + 1]) - 128.0) / 128.0
					pcm[i] = (l + r) * 0.5
				else:
					pcm[i] = (float(bytes[i]) - 128.0) / 128.0
		AudioStreamWAV.FORMAT_16_BITS:
			var stride := 4 if is_stereo else 2
			@warning_ignore("integer_division")
			var n := bytes.size() / stride
			pcm.resize(n)
			for i in range(n):
				var base := i * stride
				var lo := bytes[base]
				var hi := bytes[base + 1]
				var s: int = lo | (hi << 8)
				if s >= 32768:
					s -= 65536
				var sample_l := float(s) / 32767.0
				if is_stereo:
					lo = bytes[base + 2]
					hi = bytes[base + 3]
					s = lo | (hi << 8)
					if s >= 32768:
						s -= 65536
					pcm[i] = (sample_l + float(s) / 32767.0) * 0.5
				else:
					pcm[i] = sample_l
	return pcm

## Build an in-memory AudioStreamWAV from a float PCM buffer. No disk write.
func make_audio_stream(pcm: PackedFloat32Array, sample_rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	var bytes := PackedByteArray()
	bytes.resize(pcm.size() * 2)
	for i in range(pcm.size()):
		var val: int = int(clampf(pcm[i], -1.0, 1.0) * 32767.0) & 0xFFFF
		bytes[i * 2]     = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = bytes
	return wav

## Write a mono 16-bit PCM WAV file to path. Samples must be in [-1.0, 1.0].
func write_wav(path: String, pcm: PackedFloat32Array, sample_rate: int) -> void:
	_ensure_dirs()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("ConfigManager: cannot write WAV to " + path)
		return
	var num_samples := pcm.size()
	var byte_rate := sample_rate * 2  # 16-bit mono
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + num_samples * 2)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())  # "WAVE" + "fmt "
	f.store_32(16)            # fmt chunk size
	f.store_16(1)             # PCM format
	f.store_16(1)             # mono
	f.store_32(sample_rate)
	f.store_32(byte_rate)
	f.store_16(2)             # block align (1 channel * 2 bytes)
	f.store_16(16)            # bits per sample
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(num_samples * 2)
	for s in pcm:
		f.store_16(int(clampf(s, -1.0, 1.0) * 32767.0) & 0xFFFF)
	f.close()

func _copy_file(src: String, dest: String) -> void:
	var data := FileAccess.get_file_as_bytes(src)
	if data.is_empty():
		push_error("ConfigManager: Could not read file: " + src)
		return
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f == null:
		push_error("ConfigManager: Could not write file: " + dest)
		return
	f.store_buffer(data)
	f.close()

func _dict_to_config(d: Dictionary) -> ButtonConfig:
	var cfg := ButtonConfig.new()
	cfg.id = d.get("id", generate_id())
	cfg.type = d.get("type", "sound")
	cfg.label = d.get("label", "Button")
	cfg.wav = d.get("wav", "")
	cfg.image = d.get("image", "")
	var color_str: String = d.get("color", "#3464c8")
	cfg.color = Color.html(color_str) if Color.html_is_valid(color_str) else Color(0.2, 0.4, 0.8)
	cfg.slot = int(d.get("slot", -1))
	cfg.repeat_mode = d.get("repeat_mode", "off")
	cfg.repeat_count = int(d.get("repeat_count", 2))
	cfg.shape = d.get("shape", "square")
	cfg.effect = d.get("effect", "random")
	if cfg.type == "folder" and d.has("children") and d["children"] is Array:
		for child_data in d["children"]:
			if child_data is Dictionary:
				cfg.children.append(_dict_to_config(child_data))
	return cfg

func _config_to_dict(cfg: ButtonConfig) -> Dictionary:
	var d := {
		"id": cfg.id,
		"type": cfg.type,
		"label": cfg.label,
		"wav": cfg.wav,
		"image": cfg.image,
		"color": "#" + cfg.color.to_html(false),
		"slot": cfg.slot,
		"repeat_mode": cfg.repeat_mode,
		"repeat_count": cfg.repeat_count,
		"shape": cfg.shape,
		"effect": cfg.effect,
	}
	if cfg.type == "folder":
		d["children"] = []
		for child in cfg.children:
			(d["children"] as Array).append(_config_to_dict(child))
	return d
