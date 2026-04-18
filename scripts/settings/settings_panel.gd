extends Window

signal grid_columns_changed(columns: int)
signal grid_rows_changed(rows: int)
signal grid_line_color_changed(color: Color)

@onready var _columns_spin: SpinBox       = $MarginContainer/VBoxContainer/GridColumnsRow/ColumnsSpin
@onready var _rows_spin: SpinBox          = $MarginContainer/VBoxContainer/GridRowsRow/RowsSpin
@onready var _line_color_btn: Button      = $MarginContainer/VBoxContainer/GridLineColorRow/LineColorBtn
@onready var _output_device_opt: OptionButton = $MarginContainer/VBoxContainer/OutputDeviceRow/OutputDeviceOption
@onready var _close_btn: Button           = $MarginContainer/VBoxContainer/ButtonBar/CloseBtn

var _line_color: Color = Color(0.0, 0.0, 0.0, 0.0)

func _ready() -> void:
	_columns_spin.value_changed.connect(_on_columns_changed)
	_rows_spin.value_changed.connect(_on_rows_changed)
	_line_color_btn.pressed.connect(_on_pick_line_color_pressed)
	_output_device_opt.item_selected.connect(_on_output_device_selected)
	_close_btn.pressed.connect(hide)
	close_requested.connect(hide)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		var settings := ConfigManager.load_settings()
		_columns_spin.set_value_no_signal(settings.get("grid_columns", 5))
		_rows_spin.set_value_no_signal(settings.get("grid_rows", 4))
		var lc_hex: String = settings.get("grid_line_color", "")
		_line_color = Color.html(lc_hex) if not lc_hex.is_empty() and Color.html_is_valid(lc_hex) \
		              else Color(0.0, 0.0, 0.0, 0.0)
		_populate_output_devices(settings.get("output_device", ""))

func _populate_output_devices(saved_device: String) -> void:
	_output_device_opt.clear()
	var devices := AudioServer.get_output_device_list()
	var select_idx := 0
	for i in range(devices.size()):
		_output_device_opt.add_item(devices[i], i)
		if devices[i] == saved_device:
			select_idx = i
	_output_device_opt.select(select_idx)

func _on_output_device_selected(idx: int) -> void:
	var device: String = _output_device_opt.get_item_text(idx)
	AudioServer.set_output_device(device)
	var settings := ConfigManager.load_settings()
	settings["output_device"] = device
	ConfigManager.save_settings(settings)

func _on_columns_changed(value: float) -> void:
	var columns := int(value)
	var settings := ConfigManager.load_settings()
	settings["grid_columns"] = columns
	ConfigManager.save_settings(settings)
	grid_columns_changed.emit(columns)

func _on_rows_changed(value: float) -> void:
	var r := int(value)
	var settings := ConfigManager.load_settings()
	settings["grid_rows"] = r
	ConfigManager.save_settings(settings)
	grid_rows_changed.emit(r)

func _on_pick_line_color_pressed() -> void:
	var win := Window.new()
	win.title = "Grid Line Color"
	win.size = Vector2i(460, 560)
	win.exclusive = true
	win.wrap_controls = true

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0

	var picker := ColorPicker.new()
	picker.color = _line_color
	picker.edit_alpha = true
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
		_line_color = picker.color
		var settings := ConfigManager.load_settings()
		settings["grid_line_color"] = "#" + _line_color.to_html(true)
		ConfigManager.save_settings(settings)
		grid_line_color_changed.emit(_line_color)
		win.queue_free()
	)
	cancel_btn.pressed.connect(win.queue_free)
	win.close_requested.connect(win.queue_free)
	win.popup_centered()
