extends Button

signal right_clicked(config: ButtonConfig)
signal folder_opened(config: ButtonConfig, source_rect: Rect2)
signal drag_drop_swap(from_id: String, to_id: String)

var config: ButtonConfig = null

@onready var _bg_rect: ColorRect = $BGRect
@onready var _image_rect: TextureRect = $ImageRect
@onready var _label: Label = $ButtonLabel

var _base_color: Color = Color(0.3, 0.55, 0.3, 1.0)

func _ready() -> void:
	_label.add_theme_color_override("font_color", Color.WHITE)
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	button_down.connect(_on_press_start)
	button_up.connect(_on_press_end)

func setup(btn_config: ButtonConfig) -> void:
	config = btn_config
	_label.text = btn_config.label
	_base_color = btn_config.color
	_bg_rect.color = _base_color
	_load_image(btn_config.image)

func _on_hover_start() -> void:
	_bg_rect.color = _base_color.lightened(0.15)

func _on_hover_end() -> void:
	_bg_rect.color = _base_color

func _on_press_start() -> void:
	_bg_rect.color = _base_color.darkened(0.2)

func _on_press_end() -> void:
	_bg_rect.color = _base_color.lightened(0.15) if is_hovered() else _base_color

func _load_image(path: String) -> void:
	if path.is_empty():
		_image_rect.texture = null
		return
	_image_rect.texture = ConfigManager.load_texture(path)

func _pressed() -> void:
	folder_opened.emit(config, get_global_rect())

func _get_drag_data(_at: Vector2) -> Variant:
	if config == null:
		return null
	set_drag_preview(_make_drag_preview())
	return {"id": config.id}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).get("id", "") != config.id

func _drop_data(_at: Vector2, data: Variant) -> void:
	drag_drop_swap.emit((data as Dictionary)["id"], config.id)

func _make_drag_preview() -> Control:
	var rect := ColorRect.new()
	rect.color = Color(_base_color.r, _base_color.g, _base_color.b, 0.85)
	rect.custom_minimum_size = Vector2(80, 60)
	var lbl := Label.new()
	lbl.text = config.label
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rect.add_child(lbl)
	return rect

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_RIGHT and mbe.pressed:
			right_clicked.emit(config)
			get_viewport().set_input_as_handled()
