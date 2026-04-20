extends Control

const CELL_SIZE := 120  # must match GridDisplay.CELL_SIZE

var _grid_columns: int = 5
var _grid_rows: int = 4

# Menu item IDs
const MENU_EDIT_LABEL    := 0
const MENU_ASSIGN_WAV    := 1
const MENU_ASSIGN_IMAGE  := 2
const MENU_CLEAR_IMAGE   := 9
const MENU_CHANGE_COLOR  := 3
const MENU_DELETE        := 4
const MENU_ADD_SOUND     := 5
const MENU_ADD_SUBFOLDER := 6
const MENU_SET_REPEAT    := 7
const MENU_SET_SHAPE     := 8
const MENU_SET_EFFECT    := 10

@onready var _soundboard              = $VBoxContainer/SoundboardPanel
@onready var _context_menu: PopupMenu = $ContextMenu
@onready var _backdrop: Control       = $Backdrop
@onready var _folder_panel            = $FolderPanel
@onready var _audio_capture_panel     = $AudioCapturePanel
@onready var _audio_editor            = $AudioEditorPanel
@onready var _file_manager            = $FileManagerPanel
@onready var _settings_panel          = $SettingsPanel
@onready var _silence_btn: Button     = $VBoxContainer/TopBar/SilenceBtn
@onready var _add_sound_btn: Button   = $VBoxContainer/TopBar/AddSoundBtn
@onready var _add_folder_btn: Button  = $VBoxContainer/TopBar/AddFolderBtn
@onready var _record_btn: Button      = $VBoxContainer/TopBar/RecordBtn
@onready var _files_btn: Button       = $VBoxContainer/TopBar/FilesBtn
@onready var _settings_btn: Button    = $VBoxContainer/TopBar/SettingsBtn
@onready var _vol_slider: HSlider     = $VBoxContainer/TopBar/VolSlider
@onready var _top_bar: HBoxContainer  = $VBoxContainer/TopBar

# Context for the right-click menu
var _context_config: ButtonConfig = null
var _context_parent: ButtonConfig = null  # null = item is on root board

# Currently open folder config (null if panel is closed)
var _open_folder_config: ButtonConfig = null

func _ready() -> void:
	_soundboard.button_right_clicked.connect(_on_board_right_clicked)
	_soundboard.folder_opened.connect(_on_folder_opened)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	_backdrop.gui_input.connect(_on_backdrop_input)
	_folder_panel.child_right_clicked.connect(_on_folder_child_right_clicked)
	_folder_panel.subfolder_opened.connect(_on_folder_opened)
	_folder_panel.close_requested.connect(_close_folder_panel)
	_folder_panel.add_to_folder_requested.connect(_on_add_to_folder_requested)
	_silence_btn.pressed.connect(AudioService.stop_all)
	_add_sound_btn.pressed.connect(_on_add_sound_pressed)
	_add_folder_btn.pressed.connect(_on_add_folder_pressed)
	_record_btn.pressed.connect(_on_record_pressed)
	_vol_slider.value_changed.connect(_on_vol_changed)
	_audio_capture_panel.edit_requested.connect(_on_edit_requested)
	_audio_editor.trim_applied.connect(_on_editor_trim_applied)
	_files_btn.pressed.connect(_on_files_pressed)
	_settings_btn.pressed.connect(_on_settings_pressed)
	_settings_panel.grid_columns_changed.connect(_on_grid_columns_changed)
	_settings_panel.grid_rows_changed.connect(_on_grid_rows_changed)
	_settings_panel.grid_line_color_changed.connect(_on_grid_line_color_changed)
	_file_manager.assign_requested.connect(_on_fm_assign_requested)
	_file_manager.file_renamed.connect(_on_fm_file_renamed)
	_file_manager.file_deleted.connect(_on_fm_file_deleted)
	await get_tree().process_frame
	_grid_columns = _soundboard.get_columns()
	_grid_rows = _soundboard.get_rows()
	_update_window_size()

# ── Top bar ──────────────────────────────────────────────────────────────

func _on_add_sound_pressed() -> void:
	_show_new_button_dialog("sound")

func _on_add_folder_pressed() -> void:
	_show_new_button_dialog("folder")

func _on_vol_changed(value: float) -> void:
	var master := AudioServer.get_bus_index("Master")
	var db: float
	if value <= 0.0:
		db = -80.0
	elif value <= 0.5:
		# 0–50%: normal attenuation, 0 → -80 dB, 0.5 → 0 dB
		db = linear_to_db(value / 0.5)
	else:
		# 50–100%: gain boost, 0.5 → 0 dB, 1.0 → +12 dB (4×)
		var t := (value - 0.5) / 0.5
		db = linear_to_db(1.0 + t * 3.0)
	AudioServer.set_bus_volume_db(master, db)

func _on_record_pressed() -> void:
	if _audio_capture_panel.visible:
		_audio_capture_panel.grab_focus()
	else:
		_audio_capture_panel.popup_centered()

func _on_edit_requested(pcm: PackedFloat32Array, sample_rate: int) -> void:
	_audio_editor.load_pcm(pcm, sample_rate)
	_audio_editor.popup_centered()

func _on_editor_trim_applied(pcm: PackedFloat32Array) -> void:
	_audio_capture_panel.set_pcm(pcm)

# ── File manager ──────────────────────────────────────────────────────────────

func _on_files_pressed() -> void:
	if _file_manager.visible:
		_file_manager.grab_focus()
	else:
		_file_manager.popup_centered()

func _on_settings_pressed() -> void:
	if _settings_panel.visible:
		_settings_panel.grab_focus()
	else:
		_settings_panel.popup_centered()

func _on_grid_columns_changed(columns: int) -> void:
	_soundboard.set_columns(columns)
	_grid_columns = columns
	_update_window_size()

func _on_grid_rows_changed(rows: int) -> void:
	_soundboard.set_rows(rows)
	_grid_rows = rows
	_update_window_size()

func _update_window_size() -> void:
	var top_h := int(_soundboard.global_position.y)
	if top_h <= 0:
		top_h = 48  # TopBar minimum (44) + VBoxContainer separation (4)
	var grid_w := _grid_columns * CELL_SIZE
	var min_w := int(_top_bar.get_combined_minimum_size().x)
	DisplayServer.window_set_size(Vector2i(maxi(grid_w, min_w), top_h + _grid_rows * CELL_SIZE))

func _on_grid_line_color_changed(color: Color) -> void:
	_soundboard.set_line_color(color)

func _on_fm_assign_requested(target_id: String, path: String, file_type: String) -> void:
	var cfg: ButtonConfig = _soundboard.find_in_board(target_id)
	if cfg == null:
		return
	if file_type == "sound":
		cfg.wav = path
	else:
		cfg.image = path
	_soundboard.update_in_tree(cfg)
	_refresh_open_folder()

func _on_fm_file_renamed(old_path: String, new_path: String) -> void:
	var board: Array[ButtonConfig] = _soundboard.get_board()
	_repath_configs(board, old_path, new_path)
	ConfigManager.save_board(board)
	_soundboard.reload()
	_refresh_open_folder()

func _on_fm_file_deleted(_path: String) -> void:
	_soundboard.reload()
	_refresh_open_folder()

func _repath_configs(configs: Array[ButtonConfig], old_path: String, new_path: String) -> void:
	for cfg in configs:
		if cfg.wav == old_path:
			cfg.wav = new_path
		if cfg.image == old_path:
			cfg.image = new_path
		if cfg.type == "folder":
			_repath_configs(cfg.children, old_path, new_path)

# ── Folder panel management ──────────────────────────────────────────────

func _on_folder_opened(config: ButtonConfig, source_rect: Rect2) -> void:
	# Toggle: clicking the same folder again closes the panel.
	if _open_folder_config != null and _open_folder_config.id == config.id:
		_close_folder_panel()
		return
	if _open_folder_config != null:
		# A different folder is open — animate it out first, then open the new one.
		_folder_panel.close_animated(func():
			_backdrop.hide()
			_open_folder_config = null
			_do_open_folder(config, source_rect)
		)
		return
	_do_open_folder(config, source_rect)

func _do_open_folder(config: ButtonConfig, source_rect: Rect2) -> void:
	_open_folder_config = config
	_folder_panel.populate(config)
	_folder_panel.open_near(source_rect)
	_backdrop.show()

func _close_folder_panel() -> void:
	_folder_panel.close_animated(func():
		_backdrop.hide()
		_open_folder_config = null
	)

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close_folder_panel()

# ── Context menu ─────────────────────────────────────────────────────────

func _on_board_right_clicked(config: ButtonConfig) -> void:
	_context_config = config
	_context_parent = null
	_show_context_menu(config)

func _on_folder_child_right_clicked(child_config: ButtonConfig, folder_config: ButtonConfig) -> void:
	_context_config = child_config
	_context_parent = folder_config
	_show_context_menu(child_config)

func _show_context_menu(config: ButtonConfig) -> void:
	_context_menu.clear()
	_context_menu.add_item("Rename",          MENU_EDIT_LABEL)
	_context_menu.add_item("Assign Image...", MENU_ASSIGN_IMAGE)
	if not config.image.is_empty():
		_context_menu.add_item("Clear Image", MENU_CLEAR_IMAGE)
	_context_menu.add_item("Change Color...", MENU_CHANGE_COLOR)
	if config.type == "sound":
		_context_menu.add_item("Assign WAV...", MENU_ASSIGN_WAV)
		_context_menu.add_item("Set Repeat...", MENU_SET_REPEAT)
		_context_menu.add_item("Set Shape...",  MENU_SET_SHAPE)
		_context_menu.add_item("Set Effect...", MENU_SET_EFFECT)
	elif config.type == "folder":
		_context_menu.add_item("Add Sound to Folder...", MENU_ADD_SOUND)
		_context_menu.add_item("Add Subfolder...",        MENU_ADD_SUBFOLDER)
	_context_menu.add_separator()
	_context_menu.add_item("Delete", MENU_DELETE)
	_context_menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ZERO))

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		MENU_EDIT_LABEL:    _show_edit_label_dialog(_context_config)
		MENU_ASSIGN_WAV:    _show_assign_wav_dialog(_context_config)
		MENU_ASSIGN_IMAGE:  _show_assign_image_dialog(_context_config)
		MENU_CLEAR_IMAGE:   _clear_image(_context_config)
		MENU_CHANGE_COLOR:  _show_color_picker(_context_config)
		MENU_DELETE:        _delete_context_item()
		MENU_ADD_SOUND:     _show_add_to_folder_dialog(_context_config, "sound")
		MENU_ADD_SUBFOLDER: _show_add_to_folder_dialog(_context_config, "folder")
		MENU_SET_REPEAT:    _show_repeat_dialog(_context_config)
		MENU_SET_SHAPE:     _show_shape_dialog(_context_config)
		MENU_SET_EFFECT:    _show_effect_dialog(_context_config)

func _delete_context_item() -> void:
	if _context_parent == null:
		_soundboard.delete_button(_context_config)
		# If we just deleted an open folder, close the panel.
		if _open_folder_config != null and _open_folder_config.id == _context_config.id:
			_folder_panel.hide()
			_backdrop.hide()
			_open_folder_config = null
	else:
		_soundboard.delete_from_tree(_context_config)
		_refresh_open_folder()

func _refresh_open_folder() -> void:
	if _open_folder_config == null:
		return
	var updated: ButtonConfig = _soundboard.find_in_board(_open_folder_config.id)
	if updated == null:
		# Folder itself was deleted.
		_folder_panel.hide()
		_backdrop.hide()
		_open_folder_config = null
	else:
		_open_folder_config = updated
		_folder_panel.populate(updated)

# ── Folder "Add" button ───────────────────────────────────────────────────

func _on_add_to_folder_requested(folder_config: ButtonConfig) -> void:
	_show_add_to_folder_dialog(folder_config, "sound")

# ── Dialogs ───────────────────────────────────────────────────────────────

func _show_new_button_dialog(type: String) -> void:
	var title := "Add Folder Button" if type == "folder" else "Add Sound Button"
	var placeholder := "New Folder" if type == "folder" else "New Sound"
	_make_label_dialog(title, "", func(label: String):
		var cfg := ButtonConfig.new()
		cfg.id = ConfigManager.generate_id()
		cfg.type = type
		cfg.label = label if not label.is_empty() else placeholder
		if type == "folder":
			cfg.color = Color(0.3, 0.55, 0.3, 1.0)  # distinct green for folders
		_soundboard.add_button(cfg)
	)

func _show_add_to_folder_dialog(folder_config: ButtonConfig, type: String) -> void:
	var placeholder := "New Folder" if type == "folder" else "New Sound"
	_make_label_dialog("Add to \"" + folder_config.label + "\"", "", func(label: String):
		var cfg := ButtonConfig.new()
		cfg.id = ConfigManager.generate_id()
		cfg.type = type
		cfg.label = label if not label.is_empty() else placeholder
		if type == "folder":
			cfg.color = Color(0.3, 0.55, 0.3, 1.0)
		_soundboard.add_to_folder(folder_config.id, cfg)
		# Refresh panel only if it is currently displaying this folder.
		if _open_folder_config != null and _open_folder_config.id == folder_config.id:
			_folder_panel.populate(_open_folder_config)
	)

func _show_edit_label_dialog(config: ButtonConfig) -> void:
	_make_label_dialog("Edit Label", config.label, func(label: String):
		if not label.is_empty():
			config.label = label
		if _context_parent == null:
			_soundboard.update_button(config)
		else:
			_soundboard.update_in_tree(config)
		_refresh_open_folder()
	)

## Generic single-LineEdit dialog. `on_confirm` receives the trimmed text.
func _make_label_dialog(title: String, current: String, on_confirm: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.min_size = Vector2i(320, 0)
	var line_edit := LineEdit.new()
	line_edit.text = current
	line_edit.placeholder_text = "Enter name..."
	line_edit.max_length = 32
	dialog.add_child(line_edit)
	add_child(dialog)
	dialog.confirmed.connect(func():
		on_confirm.call(line_edit.text.strip_edges())
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
	line_edit.grab_focus()
	if not current.is_empty():
		line_edit.select_all()

func _show_assign_wav_dialog(config: ButtonConfig) -> void:
	var dialog := FileDialog.new()
	dialog.title = "Assign WAV File"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.wav ; WAV Audio Files"]
	dialog.min_size = Vector2i(700, 500)
	dialog.current_dir = ProjectSettings.globalize_path("user://sounds/")
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		config.wav = ConfigManager.import_sound(path)
		if _context_parent == null:
			_soundboard.update_button(config)
		else:
			_soundboard.update_in_tree(config)
		_refresh_open_folder()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _show_assign_image_dialog(config: ButtonConfig) -> void:
	var dialog := FileDialog.new()
	dialog.title = "Assign Button Image"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.png,*.jpg,*.jpeg,*.webp ; Image Files"]
	dialog.min_size = Vector2i(700, 500)
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		config.image = ConfigManager.import_image(path)
		if _context_parent == null:
			_soundboard.update_button(config)
		else:
			_soundboard.update_in_tree(config)
		_refresh_open_folder()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _clear_image(config: ButtonConfig) -> void:
	config.image = ""
	if _context_parent == null:
		_soundboard.update_button(config)
	else:
		_soundboard.update_in_tree(config)
	_refresh_open_folder()

func _show_shape_dialog(config: ButtonConfig) -> void:
	var win := Window.new()
	win.title = "Button Shape"
	win.size = Vector2i(260, 160)
	win.exclusive = true
	win.wrap_controls = true

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var option := OptionButton.new()
	option.add_item("Square", 0)
	option.add_item("Circle", 1)
	option.add_item("Star",   2)
	option.add_item("Heart",  3)
	match config.shape:
		"circle": option.selected = 1
		"star":   option.selected = 2
		"heart":  option.selected = 3
		_:        option.selected = 0

	var btn_bar := HBoxContainer.new()
	var spacer  := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var apply_btn  := Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(80, 0)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 0)
	btn_bar.add_child(spacer)
	btn_bar.add_child(apply_btn)
	btn_bar.add_child(cancel_btn)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(option)
	vbox.add_child(fill)
	vbox.add_child(btn_bar)
	margin.add_child(vbox)
	win.add_child(margin)
	add_child(win)

	apply_btn.pressed.connect(func():
		const SHAPES := ["square", "circle", "star", "heart"]
		config.shape = SHAPES[option.selected]
		if _context_parent == null:
			_soundboard.update_button(config)
		else:
			_soundboard.update_in_tree(config)
		_refresh_open_folder()
		win.queue_free()
	)
	cancel_btn.pressed.connect(win.queue_free)
	win.close_requested.connect(win.queue_free)
	win.popup_centered()

func _show_repeat_dialog(config: ButtonConfig) -> void:
	var win := Window.new()
	win.title = "Repeat Settings"
	win.size = Vector2i(300, 180)
	win.exclusive = true
	win.wrap_controls = true

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 10)

	var mode_option := OptionButton.new()
	mode_option.add_item("Play once", 0)
	mode_option.add_item("Repeat N times", 1)
	mode_option.add_item("Loop forever", 2)

	var count_row := HBoxContainer.new()
	var count_label := Label.new()
	count_label.text = "Play count:"
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var count_spin := SpinBox.new()
	count_spin.min_value = 2
	count_spin.max_value = 99
	count_spin.value = maxi(2, config.repeat_count)
	count_row.add_child(count_label)
	count_row.add_child(count_spin)

	match config.repeat_mode:
		"count":    mode_option.selected = 1
		"infinite": mode_option.selected = 2
		_:          mode_option.selected = 0
	count_row.visible = (mode_option.selected == 1)
	mode_option.item_selected.connect(func(idx: int):
		count_row.visible = (idx == 1)
		win.size = Vector2i(300, 210 if idx == 1 else 180)
	)

	var btn_bar := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(80, 0)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 0)
	btn_bar.add_child(spacer)
	btn_bar.add_child(apply_btn)
	btn_bar.add_child(cancel_btn)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	vbox.add_child(mode_option)
	vbox.add_child(count_row)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(fill)
	vbox.add_child(btn_bar)
	margin.add_child(vbox)
	win.add_child(margin)
	add_child(win)

	apply_btn.pressed.connect(func():
		match mode_option.selected:
			0: config.repeat_mode = "off"
			1: config.repeat_mode = "count"; config.repeat_count = int(count_spin.value)
			2: config.repeat_mode = "infinite"
		if _context_parent == null:
			_soundboard.update_button(config)
		else:
			_soundboard.update_in_tree(config)
		_refresh_open_folder()
		win.queue_free()
	)
	cancel_btn.pressed.connect(win.queue_free)
	win.close_requested.connect(win.queue_free)
	win.popup_centered()

func _show_effect_dialog(config: ButtonConfig) -> void:
	var win := Window.new()
	win.title = "Playback Effect"
	win.size = Vector2i(260, 160)
	win.exclusive = true
	win.wrap_controls = true

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var option := OptionButton.new()
	option.add_item("Random",  0)
	option.add_item("Plasma",  1)
	option.add_item("Fire",    2)
	option.add_item("Glitch",  3)
	option.add_item("Ripple",  4)
	match config.effect:
		"plasma": option.selected = 1
		"fire":   option.selected = 2
		"glitch": option.selected = 3
		"ripple": option.selected = 4
		_:        option.selected = 0

	var btn_bar := HBoxContainer.new()
	var spacer  := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var apply_btn  := Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(80, 0)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 0)
	btn_bar.add_child(spacer)
	btn_bar.add_child(apply_btn)
	btn_bar.add_child(cancel_btn)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(option)
	vbox.add_child(fill)
	vbox.add_child(btn_bar)
	margin.add_child(vbox)
	win.add_child(margin)
	add_child(win)

	apply_btn.pressed.connect(func():
		const EFFECTS := ["random", "plasma", "fire", "glitch", "ripple"]
		config.effect = EFFECTS[option.selected]
		if _context_parent == null:
			_soundboard.update_button(config)
		else:
			_soundboard.update_in_tree(config)
		_refresh_open_folder()
		win.queue_free()
	)
	cancel_btn.pressed.connect(win.queue_free)
	win.close_requested.connect(win.queue_free)
	win.popup_centered()

func _show_color_picker(config: ButtonConfig) -> void:
	var win := Window.new()
	win.title = "Choose Button Color"
	win.size = Vector2i(460, 560)
	win.exclusive = true
	win.wrap_controls = true

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0

	var picker := ColorPicker.new()
	picker.color = config.color
	picker.edit_alpha = false
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var btn_bar := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(90, 0)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(90, 0)
	btn_bar.add_child(spacer)
	btn_bar.add_child(apply_btn)
	btn_bar.add_child(cancel_btn)

	vbox.add_child(picker)
	vbox.add_child(btn_bar)
	win.add_child(vbox)
	add_child(win)

	apply_btn.pressed.connect(func():
		config.color = picker.color
		if _context_parent == null:
			_soundboard.update_button(config)
		else:
			_soundboard.update_in_tree(config)
		_refresh_open_folder()
		win.queue_free()
	)
	cancel_btn.pressed.connect(win.queue_free)
	win.close_requested.connect(win.queue_free)
	win.popup_centered()
