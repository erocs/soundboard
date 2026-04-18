extends Window

## Emitted when the user confirms a trim. Contains the sliced PCM.
signal trim_applied(pcm: PackedFloat32Array)

@onready var _waveform: WaveformDisplay  = $MarginContainer/VBoxContainer/WaveformDisplay
@onready var _play_btn: Button           = $MarginContainer/VBoxContainer/Controls/PlayBtn
@onready var _time_label: Label          = $MarginContainer/VBoxContainer/Controls/TimeLabel
@onready var _in_label: Label            = $MarginContainer/VBoxContainer/Controls/InLabel
@onready var _out_label: Label           = $MarginContainer/VBoxContainer/Controls/OutLabel
@onready var _dur_label: Label           = $MarginContainer/VBoxContainer/Controls/DurLabel
@onready var _apply_btn: Button          = $MarginContainer/VBoxContainer/Actions/ApplyBtn
@onready var _cancel_btn: Button         = $MarginContainer/VBoxContainer/Actions/CancelBtn
@onready var _player: AudioStreamPlayer  = $AudioStreamPlayer

var _pcm: PackedFloat32Array = []
var _sample_rate: int = 44100
var _in_frame: int = 0
var _out_frame: int = 0

func _ready() -> void:
	_play_btn.pressed.connect(_on_play_pressed)
	_apply_btn.pressed.connect(_on_apply_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_waveform.trim_changed.connect(_on_trim_changed)
	_player.finished.connect(_on_player_finished)
	close_requested.connect(_on_cancel_pressed)

## Load PCM into the editor. Call before popup_centered().
func load_pcm(pcm: PackedFloat32Array, sample_rate: int) -> void:
	_pcm = pcm
	_sample_rate = sample_rate
	_in_frame = 0
	_out_frame = pcm.size()
	_player.stop()
	_play_btn.text = "Play"
	_waveform.load_samples(pcm, _in_frame, _out_frame)
	_update_labels()

func _process(_delta: float) -> void:
	if not _player.playing:
		return
	var pos_sec := _player.get_playback_position()
	var current_frame := _in_frame + int(pos_sec * float(_sample_rate))
	_waveform.set_playhead(current_frame)
	var total_sec := float(_out_frame - _in_frame) / float(_sample_rate)
	_time_label.text = "%.2fs / %.2fs" % [pos_sec, total_sec]

# ── Playback ──────────────────────────────────────────────────────────────

func _on_play_pressed() -> void:
	if _player.playing:
		_player.stop()
		_play_btn.text = "Play"
		_waveform.set_playhead(-1)
		return
	var trimmed := _pcm.slice(_in_frame, _out_frame)
	_player.stream = ConfigManager.make_audio_stream(trimmed, _sample_rate)
	_player.play()
	_play_btn.text = "Stop"

func _on_player_finished() -> void:
	_play_btn.text = "Play"
	_waveform.set_playhead(-1)
	_update_labels()

# ── Trim markers ──────────────────────────────────────────────────────────

func _on_trim_changed(in_frame: int, out_frame: int) -> void:
	_in_frame = in_frame
	_out_frame = out_frame
	_update_labels()

# ── Actions ───────────────────────────────────────────────────────────────

func _on_apply_pressed() -> void:
	_player.stop()
	trim_applied.emit(_pcm.slice(_in_frame, _out_frame))
	hide()

func _on_cancel_pressed() -> void:
	_player.stop()
	_play_btn.text = "Play"
	_waveform.set_playhead(-1)
	hide()

# ── Helpers ───────────────────────────────────────────────────────────────

func _update_labels() -> void:
	var in_sec  := float(_in_frame)  / float(_sample_rate)
	var out_sec := float(_out_frame) / float(_sample_rate)
	var dur_sec := out_sec - in_sec
	_in_label.text   = "In: %.2fs"  % in_sec
	_out_label.text  = "Out: %.2fs" % out_sec
	_dur_label.text  = "Dur: %.2fs" % dur_sec
	_time_label.text = "0.00s / %.2fs" % dur_sec
