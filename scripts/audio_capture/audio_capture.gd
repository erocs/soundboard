extends Window

signal recording_saved(path: String)
signal edit_requested(pcm: PackedFloat32Array, sample_rate: int)

const BUS_NAME        := "Capture"
const SYS_SAMPLE_RATE := 48000
const SYS_RAW_PATH    := "user://sounds/_sysrec_tmp.s16le"

@onready var _source_option: OptionButton       = $MarginContainer/VBoxContainer/SourceRow/SourceOption
@onready var _meter_row: HBoxContainer          = $MarginContainer/VBoxContainer/MeterRow
@onready var _level_meter: ProgressBar          = $MarginContainer/VBoxContainer/MeterRow/LevelMeter
@onready var _gain_row: HBoxContainer           = $MarginContainer/VBoxContainer/GainRow
@onready var _gain_slider: HSlider              = $MarginContainer/VBoxContainer/GainRow/GainSlider
@onready var _gain_value_label: Label           = $MarginContainer/VBoxContainer/GainRow/GainValueLabel
@onready var _filename_edit: LineEdit           = $MarginContainer/VBoxContainer/FilenameRow/FilenameEdit
@onready var _status_label: Label               = $MarginContainer/VBoxContainer/StatusLabel
@onready var _record_btn: Button                = $MarginContainer/VBoxContainer/ButtonsRow/RecordBtn
@onready var _play_btn: Button                  = $MarginContainer/VBoxContainer/ButtonsRow/PlayBtn
@onready var _save_btn: Button                  = $MarginContainer/VBoxContainer/ButtonsRow/SaveBtn
@onready var _discard_btn: Button               = $MarginContainer/VBoxContainer/ButtonsRow/DiscardBtn
@onready var _edit_btn: Button                  = $MarginContainer/VBoxContainer/ButtonsRow/EditBtn
@onready var _load_wav_btn: Button              = $MarginContainer/VBoxContainer/ButtonsRow/LoadWavBtn
@onready var _player: AudioStreamPlayer         = $AudioStreamPlayer
@onready var _preview_player: AudioStreamPlayer = $PreviewPlayer

var _recording := false
var _pcm: PackedFloat32Array = []
var _sample_rate := 44100
var _capture_effect: AudioEffectCapture = null
var _record_start_usec: int = 0
var _input_gain: float = 1.0
var _sys_record_pid := -1

func _ready() -> void:
	_setup_capture_bus()
	_play_btn.disabled = true
	_save_btn.disabled = true
	_discard_btn.disabled = true
	_edit_btn.disabled = true
	_source_option.add_item("Microphone", 0)
	_source_option.add_item("System Audio", 1)
	if OS.execute("where", ["ffmpeg"], []) != 0:
		_source_option.set_item_disabled(1, true)
		_source_option.set_item_text(1, "System Audio (ffmpeg not found)")
	_source_option.item_selected.connect(_on_source_changed)
	_record_btn.pressed.connect(_on_record_pressed)
	_play_btn.pressed.connect(_on_play_pressed)
	_save_btn.pressed.connect(_on_save_pressed)
	_discard_btn.pressed.connect(_on_discard_pressed)
	_edit_btn.pressed.connect(_on_edit_pressed)
	_load_wav_btn.pressed.connect(_on_load_wav_pressed)
	_gain_slider.value_changed.connect(_on_gain_changed)
	_preview_player.finished.connect(_on_preview_finished)
	close_requested.connect(_on_close_requested)
	_filename_edit.text = _generate_filename()

func _setup_capture_bus() -> void:
	var bus_idx := AudioServer.get_bus_index(BUS_NAME)
	if bus_idx == -1:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, BUS_NAME)
		AudioServer.set_bus_send(bus_idx, "Master")
		AudioServer.set_bus_mute(bus_idx, true)
		AudioServer.add_bus_effect(bus_idx, AudioEffectCapture.new())
	_capture_effect = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectCapture
	_player.bus = BUS_NAME
	_player.stream = AudioStreamMicrophone.new()

func _on_source_changed(_index: int) -> void:
	var is_mic := _source_option.selected == 0
	_meter_row.visible = is_mic
	_gain_row.visible = is_mic

func _process(_delta: float) -> void:
	if not _recording:
		return
	var elapsed := (Time.get_ticks_usec() - _record_start_usec) / 1_000_000.0
	_status_label.text = "Recording: %.1fs" % elapsed
	if _source_option.selected != 0 or _capture_effect == null:
		return
	var available := _capture_effect.get_frames_available()
	if available <= 0:
		return
	var buffer: PackedVector2Array = _capture_effect.get_buffer(available)
	var rms_sum := 0.0
	for sample in buffer:
		var mono := clampf((sample.x + sample.y) * 0.5 * _input_gain, -1.0, 1.0)
		_pcm.append(mono)
		rms_sum += mono * mono
	_level_meter.value = clampf(sqrt(rms_sum / maxi(1, buffer.size())) * 4.0, 0.0, 1.0)

func _on_record_pressed() -> void:
	if _recording:
		_stop_recording()
	else:
		_start_recording()

func _start_recording() -> void:
	_preview_player.stop()
	_play_btn.text = "Preview"
	_pcm.clear()
	_record_btn.text = "Stop"
	_play_btn.disabled = true
	_save_btn.disabled = true
	_discard_btn.disabled = true
	_edit_btn.disabled = true
	_load_wav_btn.disabled = true
	_source_option.disabled = true
	_record_start_usec = Time.get_ticks_usec()
	_recording = true
	if _source_option.selected == 0:
		_sample_rate = int(AudioServer.get_mix_rate())
		_capture_effect.clear_buffer()
		_player.play()
	else:
		_sample_rate = SYS_SAMPLE_RATE
		var raw_abs := ProjectSettings.globalize_path(SYS_RAW_PATH)
		var args: PackedStringArray = [
			"-nostdin", "-loglevel", "error",
			"-f", "wasapi", "-loopback", "-i", "default",
			"-f", "s16le", "-ar", str(SYS_SAMPLE_RATE), "-ac", "2", "-y", raw_abs
		]
		_sys_record_pid = OS.create_process("ffmpeg", args)
		if _sys_record_pid <= 0:
			push_error("AudioCapture: failed to launch ffmpeg")
			_recording = false
			_record_btn.text = "Record"
			_source_option.disabled = false
			_load_wav_btn.disabled = false
			_status_label.text = "Failed to start ffmpeg."

func _stop_recording() -> void:
	_recording = false
	_record_btn.text = "Record"
	_source_option.disabled = false
	_load_wav_btn.disabled = false
	if _source_option.selected == 0:
		_player.stop()
		_level_meter.value = 0.0
		if _pcm.size() > 0:
			var elapsed := (Time.get_ticks_usec() - _record_start_usec) / 1_000_000.0
			_status_label.text = "Captured %.1fs — ready to save." % elapsed
			_enable_post_capture_buttons()
		else:
			_status_label.text = "No audio captured."
	else:
		if _sys_record_pid > 0:
			OS.kill(_sys_record_pid)
			_sys_record_pid = -1
		_status_label.text = "Processing..."
		var raw_bytes := FileAccess.get_file_as_bytes(SYS_RAW_PATH)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SYS_RAW_PATH))
		if raw_bytes.is_empty():
			_status_label.text = "No audio — check that WASAPI loopback is available."
			return
		var wav := AudioStreamWAV.new()
		wav.data = raw_bytes
		wav.mix_rate = SYS_SAMPLE_RATE
		wav.stereo = true
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		_pcm = ConfigManager.wav_to_pcm(wav)
		if _pcm.is_empty():
			_status_label.text = "No audio captured."
			return
		var elapsed := (Time.get_ticks_usec() - _record_start_usec) / 1_000_000.0
		_status_label.text = "Captured %.1fs — ready to save." % elapsed
		_enable_post_capture_buttons()

func _enable_post_capture_buttons() -> void:
	_play_btn.disabled = false
	_save_btn.disabled = false
	_discard_btn.disabled = false
	_edit_btn.disabled = false

func _on_save_pressed() -> void:
	var fname := _filename_edit.text.strip_edges()
	if fname.is_empty():
		fname = _generate_filename()
	if not fname.ends_with(".wav"):
		fname += ".wav"
	var path := "user://sounds/" + fname
	ConfigManager.write_wav(path, _pcm, _sample_rate)
	_preview_player.stop()
	_play_btn.text = "Preview"
	_pcm.clear()
	_play_btn.disabled = true
	_save_btn.disabled = true
	_discard_btn.disabled = true
	_edit_btn.disabled = true
	_status_label.text = "Saved: " + fname
	_filename_edit.text = _generate_filename()
	recording_saved.emit(path)
	hide()

func _on_play_pressed() -> void:
	if _preview_player.playing:
		_preview_player.stop()
		_play_btn.text = "Preview"
		return
	_preview_player.stream = ConfigManager.make_audio_stream(_pcm, _sample_rate)
	_preview_player.play()
	_play_btn.text = "Stop"

func _on_preview_finished() -> void:
	_play_btn.text = "Preview"

func _on_edit_pressed() -> void:
	_preview_player.stop()
	_play_btn.text = "Preview"
	edit_requested.emit(_pcm.duplicate(), _sample_rate)

## Called by main when the editor returns a trimmed buffer.
func set_pcm(pcm: PackedFloat32Array) -> void:
	_pcm = pcm
	var duration := float(pcm.size()) / float(_sample_rate)
	_status_label.text = "Trimmed: %.1fs — ready to save." % duration

func _on_gain_changed(value: float) -> void:
	_input_gain = value
	_gain_value_label.text = "%.2fx" % value

func _on_discard_pressed() -> void:
	_preview_player.stop()
	_play_btn.text = "Preview"
	_pcm.clear()
	_play_btn.disabled = true
	_save_btn.disabled = true
	_discard_btn.disabled = true
	_edit_btn.disabled = true
	hide()

func _on_load_wav_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Load WAV for Editing"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.wav ; WAV Files"]
	dialog.min_size = Vector2i(700, 500)
	dialog.current_dir = ProjectSettings.globalize_path("user://sounds/")
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var stream := ConfigManager.load_audio_stream(path) as AudioStreamWAV
		if stream == null:
			_status_label.text = "Failed to load: " + path.get_file()
			dialog.queue_free()
			return
		_pcm = ConfigManager.wav_to_pcm(stream)
		_sample_rate = stream.mix_rate
		_filename_edit.text = path.get_file().get_basename()
		_status_label.text = "Loaded: " + path.get_file()
		_enable_post_capture_buttons()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _on_close_requested() -> void:
	if _recording:
		_stop_recording()
	hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _sys_record_pid > 0:
		OS.kill(_sys_record_pid)

func _generate_filename() -> String:
	return "rec_%d" % int(Time.get_unix_time_from_system())
