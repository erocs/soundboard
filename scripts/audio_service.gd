extends Node

## Maximum number of sounds that can play simultaneously.
## If all players are busy the oldest one is interrupted.
const MAX_CONCURRENT := 4

signal playback_started(path: String)
signal playback_stopped(path: String)
signal playback_repeated(path: String, plays_remaining: int)

var _players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	var saved_device: String = ConfigManager.load_settings().get("output_device", "")
	if not saved_device.is_empty() and saved_device in AudioServer.get_output_device_list():
		AudioServer.set_output_device(saved_device)
	for i in range(MAX_CONCURRENT):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
		p.finished.connect(_on_player_finished.bind(p))

## Toggle playback for the given path.
## repeat_mode: "off" | "count" | "infinite"
## repeat_count: total plays when repeat_mode == "count"
func toggle(path: String, repeat_mode: String = "off", repeat_count: int = 1) -> void:
	if path.is_empty():
		return
	for p in _players:
		if p.playing and p.get_meta("sound_path", "") == path:
			p.stop()
			playback_stopped.emit(path)
			return
	var stream := ConfigManager.load_audio_stream(path)
	if stream == null:
		push_warning("AudioService: could not load: " + path)
		return
	var player := _get_free_player()
	if player.playing:
		playback_stopped.emit(player.get_meta("sound_path", ""))
		player.stop()
	player.set_meta("sound_path", path)
	player.set_meta("repeat_mode", repeat_mode)
	player.set_meta("plays_remaining", repeat_count - 1)
	player.stream = stream
	player.play()
	playback_started.emit(path)

## Stop every active player immediately.
func stop_all() -> void:
	for p in _players:
		if p.playing:
			playback_stopped.emit(p.get_meta("sound_path", ""))
			p.stop()

func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _on_player_finished(player: AudioStreamPlayer) -> void:
	var path: String = player.get_meta("sound_path", "")
	var mode: String = player.get_meta("repeat_mode", "off")
	if mode == "infinite":
		player.play()
		return
	if mode == "count":
		var remaining: int = player.get_meta("plays_remaining", 0)
		if remaining > 0:
			player.set_meta("plays_remaining", remaining - 1)
			player.play()
			playback_repeated.emit(path, remaining)
			return
	playback_stopped.emit(path)
