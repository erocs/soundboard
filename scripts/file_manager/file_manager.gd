extends Window

## Emitted when the user assigns a file to a button.
signal assign_requested(target_id: String, path: String, file_type: String)
## Emitted after a file is renamed on disk.
signal file_renamed(old_path: String, new_path: String)
## Emitted after a file is deleted from disk.
signal file_deleted(path: String)

const SOUND_EXTS := ["wav"]
const IMAGE_EXTS := ["png", "jpg", "jpeg", "webp"]

@onready var _tree: Tree = $MarginContainer/VBoxContainer/HSplitContainer/FileTree
@onready var _no_sel_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/PreviewContainer/NoSelectionLabel
@onready var _preview_waveform: WaveformDisplay = $MarginContainer/VBoxContainer/HSplitContainer/PreviewContainer/PreviewWaveform
@onready var _preview_image: TextureRect = $MarginContainer/VBoxContainer/HSplitContainer/PreviewContainer/PreviewImage
@onready var _wave_controls: HBoxContainer = $MarginContainer/VBoxContainer/HSplitContainer/PreviewContainer/WaveControls
@onready var _play_btn: Button = $MarginContainer/VBoxContainer/HSplitContainer/PreviewContainer/WaveControls/PlayPreviewBtn
@onready var _import_sound_btn: Button = $MarginContainer/VBoxContainer/Toolbar/ImportSoundBtn
@onready var _import_image_btn: Button = $MarginContainer/VBoxContainer/Toolbar/ImportImageBtn
@onready var _rename_btn: Button = $MarginContainer/VBoxContainer/Toolbar/RenameBtn
@onready var _delete_btn: Button = $MarginContainer/VBoxContainer/Toolbar/DeleteBtn
@onready var _assign_btn: Button = $MarginContainer/VBoxContainer/Toolbar/AssignBtn
@onready var _close_btn: Button = $MarginContainer/VBoxContainer/Toolbar/CloseBtn
@onready var _player: AudioStreamPlayer = $AudioStreamPlayer

var _selected_path: String = ""

func _ready() -> void:
	_preview_waveform.read_only = true
	_tree.hide_root = true
	_tree.item_selected.connect(_on_item_selected)
	_tree.nothing_selected.connect(_on_nothing_selected)
	_import_sound_btn.pressed.connect(_on_import_sound_pressed)
	_import_image_btn.pressed.connect(_on_import_image_pressed)
	_rename_btn.pressed.connect(_on_rename_pressed)
	_delete_btn.pressed.connect(_on_delete_pressed)
	_assign_btn.pressed.connect(_on_assign_pressed)
	_play_btn.pressed.connect(_on_play_pressed)
	_close_btn.pressed.connect(hide)
	_player.finished.connect(_on_player_finished)
	close_requested.connect(hide)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_tree()

# ── Tree ──────────────────────────────────────────────────────────────────────

func _refresh_tree() -> void:
	_player.stop()
	_play_btn.text = "Play"
	_tree.clear()
	var root := _tree.create_item()

	var sounds_item := _tree.create_item(root)
	sounds_item.set_text(0, "Sounds")
	sounds_item.set_selectable(0, false)
	sounds_item.set_collapsed(false)
	_list_dir("user://sounds/", SOUND_EXTS, sounds_item)

	var images_item := _tree.create_item(root)
	images_item.set_text(0, "Images")
	images_item.set_selectable(0, false)
	images_item.set_collapsed(false)
	_list_dir("user://images/", IMAGE_EXTS, images_item)

	_clear_preview()

func _list_dir(dir_path: String, exts: Array, parent: TreeItem) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var files: Array[String] = []
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			if fname.get_extension().to_lower() in exts:
				files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for f in files:
		var item := _tree.create_item(parent)
		item.set_text(0, f)
		item.set_metadata(0, dir_path + f)

func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		_clear_preview()
		return
	var meta = item.get_metadata(0)
	if not (meta is String):
		_clear_preview()
		return
	_selected_path = meta as String
	_rename_btn.disabled = false
	_delete_btn.disabled = false
	_assign_btn.disabled = false
	_show_preview(_selected_path)

func _on_nothing_selected() -> void:
	_clear_preview()

# ── Preview ───────────────────────────────────────────────────────────────────

func _show_preview(path: String) -> void:
	_player.stop()
	_play_btn.text = "Play"
	var ext := path.get_extension().to_lower()
	if ext == "wav":
		_preview_image.hide()
		_no_sel_label.hide()
		var stream := ConfigManager.load_audio_stream(path) as AudioStreamWAV
		if stream != null:
			var pcm := ConfigManager.wav_to_pcm(stream)
			if not pcm.is_empty():
				_preview_waveform.load_samples(pcm, 0, pcm.size())
				_preview_waveform.show()
			else:
				_preview_waveform.hide()
		else:
			_preview_waveform.hide()
		_wave_controls.show()
	elif ext in IMAGE_EXTS:
		_preview_waveform.hide()
		_wave_controls.hide()
		_no_sel_label.hide()
		_preview_image.texture = ConfigManager.load_texture(path)
		_preview_image.show()
	else:
		_clear_preview()

func _clear_preview() -> void:
	_selected_path = ""
	_player.stop()
	_play_btn.text = "Play"
	_preview_waveform.hide()
	_preview_image.hide()
	_wave_controls.hide()
	_no_sel_label.show()
	_rename_btn.disabled = true
	_delete_btn.disabled = true
	_assign_btn.disabled = true

# ── WAV playback ──────────────────────────────────────────────────────────────

func _on_play_pressed() -> void:
	if _player.playing:
		_player.stop()
		_play_btn.text = "Play"
		return
	var stream := ConfigManager.load_audio_stream(_selected_path)
	if stream == null:
		return
	_player.stream = stream
	_player.play()
	_play_btn.text = "Stop"

func _on_player_finished() -> void:
	_play_btn.text = "Play"

# ── Import ────────────────────────────────────────────────────────────────────

func _on_import_sound_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Import Sound"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.wav ; WAV Audio Files"]
	dialog.min_size = Vector2i(700, 500)
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		ConfigManager.import_sound(path)
		_refresh_tree()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _on_import_image_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Import Image"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.png,*.jpg,*.jpeg,*.webp ; Image Files"]
	dialog.min_size = Vector2i(700, 500)
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		ConfigManager.import_image(path)
		_refresh_tree()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

# ── Rename ────────────────────────────────────────────────────────────────────

func _on_rename_pressed() -> void:
	if _selected_path.is_empty():
		return
	var old_name := _selected_path.get_file()
	var dir_path := _selected_path.get_base_dir()

	var dialog := ConfirmationDialog.new()
	dialog.title = "Rename File"
	dialog.min_size = Vector2i(320, 0)
	var line := LineEdit.new()
	line.text = old_name
	dialog.add_child(line)
	add_child(dialog)
	dialog.confirmed.connect(func():
		var new_name := line.text.strip_edges()
		if new_name.is_empty() or new_name == old_name:
			dialog.queue_free()
			return
		var dir := DirAccess.open(dir_path)
		if dir == null:
			dialog.queue_free()
			return
		var err := dir.rename(old_name, new_name)
		if err != OK:
			push_warning("FileManager: rename failed (%d)" % err)
		else:
			file_renamed.emit(_selected_path, dir_path + "/" + new_name)
		_refresh_tree()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
	line.grab_focus()
	line.select_all()

# ── Delete ────────────────────────────────────────────────────────────────────

func _on_delete_pressed() -> void:
	if _selected_path.is_empty():
		return
	var fname := _selected_path.get_file()
	var confirm := ConfirmationDialog.new()
	confirm.title = "Delete File"
	confirm.dialog_text = "Delete \"%s\"?\nThis cannot be undone." % fname
	add_child(confirm)
	confirm.confirmed.connect(func():
		var dir := DirAccess.open(_selected_path.get_base_dir())
		if dir != null:
			dir.remove(_selected_path.get_file())
		file_deleted.emit(_selected_path)
		_refresh_tree()
		confirm.queue_free()
	)
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

# ── Assign to Button ──────────────────────────────────────────────────────────

func _on_assign_pressed() -> void:
	if _selected_path.is_empty():
		return
	var ext := _selected_path.get_extension().to_lower()
	var file_type := "sound" if ext == "wav" else "image"

	var all_configs: Array[ButtonConfig] = []
	var all_labels: Array[String] = []
	_collect_buttons_with_path(ConfigManager.load_board(), all_configs, all_labels, "")

	# Sounds can only be assigned to sound buttons; images work on any button.
	var eligible: Array[ButtonConfig] = []
	var eligible_labels: Array[String] = []
	for i in range(all_configs.size()):
		if file_type == "sound" and all_configs[i].type != "sound":
			continue
		eligible.append(all_configs[i])
		eligible_labels.append(all_labels[i])

	if eligible.is_empty():
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Assign \"%s\" to:" % _selected_path.get_file()
	dialog.min_size = Vector2i(360, 0)
	var option := OptionButton.new()
	for lbl in eligible_labels:
		option.add_item(lbl)
	dialog.add_child(option)
	add_child(dialog)
	dialog.confirmed.connect(func():
		assign_requested.emit(eligible[option.selected].id, _selected_path, file_type)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _collect_buttons_with_path(configs: Array[ButtonConfig], out: Array[ButtonConfig], labels: Array[String], prefix: String) -> void:
	for cfg in configs:
		out.append(cfg)
		var type_hint := " [folder]" if cfg.type == "folder" else ""
		labels.append(prefix + cfg.label + type_hint)
		if cfg.type == "folder":
			_collect_buttons_with_path(cfg.children, out, labels, cfg.label + " > ")
