extends PanelContainer

const GRID_COLUMNS := 4
const BUTTON_SIZE := 120.0
const PANEL_MARGIN := 12.0
const HEADER_HEIGHT := 44.0
const MAX_PANEL_W := 560.0
const MAX_PANEL_H := 460.0

var _sound_button_scene := preload("res://scenes/soundboard/sound_button.tscn")
var _folder_button_scene := preload("res://scenes/soundboard/folder_button.tscn")
var _current_config: ButtonConfig = null
var _active_tween: Tween = null

@onready var _title_label: Label = $VBoxContainer/Header/TitleLabel
@onready var _close_btn: Button = $VBoxContainer/Header/CloseBtn
@onready var _add_btn: Button = $VBoxContainer/Header/AddBtn
@onready var _grid: GridContainer = $VBoxContainer/ScrollContainer/ButtonGrid

signal child_right_clicked(child_config: ButtonConfig, folder_config: ButtonConfig)
signal subfolder_opened(config: ButtonConfig, source_rect: Rect2)
signal close_requested()
signal add_to_folder_requested(folder_config: ButtonConfig)

func _ready() -> void:
	_grid.columns = GRID_COLUMNS
	_close_btn.pressed.connect(func(): close_requested.emit())
	_add_btn.pressed.connect(func(): add_to_folder_requested.emit(_current_config))

func populate(config: ButtonConfig) -> void:
	_current_config = config
	_title_label.text = config.label
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for child_cfg in config.children:
		_add_button_node(child_cfg)

func _add_button_node(child_cfg: ButtonConfig) -> void:
	if child_cfg.type == "sound":
		var btn := _sound_button_scene.instantiate()
		_grid.add_child(btn)
		btn.setup(child_cfg)
		btn.right_clicked.connect(func(cfg): child_right_clicked.emit(cfg, _current_config))
	elif child_cfg.type == "folder":
		var btn := _folder_button_scene.instantiate()
		_grid.add_child(btn)
		btn.setup(child_cfg)
		btn.right_clicked.connect(func(cfg): child_right_clicked.emit(cfg, _current_config))
		btn.folder_opened.connect(func(cfg, rect): subfolder_opened.emit(cfg, rect))

func open_near(btn_global_rect: Rect2) -> void:
	var count: int = maxi(1, _current_config.children.size())
	var cols: int = mini(GRID_COLUMNS, count)
	var rows: int = ceili(float(count) / float(GRID_COLUMNS))
	var panel_w: float = clampf(cols * BUTTON_SIZE + PANEL_MARGIN * 2, 220.0, MAX_PANEL_W)
	var panel_h: float = clampf(rows * BUTTON_SIZE + HEADER_HEIGHT + PANEL_MARGIN * 2, 160.0, MAX_PANEL_H)

	var vp: Vector2 = get_viewport_rect().size
	var pos := Vector2(btn_global_rect.position.x, btn_global_rect.end.y + 6.0)
	pos.x = clampf(pos.x, 6.0, vp.x - panel_w - 6.0)
	pos.y = clampf(pos.y, 6.0, vp.y - panel_h - 6.0)

	size = Vector2(panel_w, panel_h)
	position = pos
	pivot_offset = btn_global_rect.get_center() - pos
	scale = Vector2.ZERO
	show()

	if _active_tween:
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "scale", Vector2.ONE, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func close_animated(on_done: Callable = Callable()) -> void:
	if _active_tween:
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "scale", Vector2.ZERO, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_callback(func():
		hide()
		if on_done.is_valid():
			on_done.call()
	)

func get_current_config() -> ButtonConfig:
	return _current_config
