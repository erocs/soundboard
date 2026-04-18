extends ScrollContainer

signal button_right_clicked(config: ButtonConfig)
signal folder_opened(config: ButtonConfig, source_rect: Rect2)

@onready var _grid: GridDisplay = $GridDisplay

var _sound_button_scene := preload("res://scenes/soundboard/sound_button.tscn")
var _folder_button_scene := preload("res://scenes/soundboard/folder_button.tscn")
var _board: Array[ButtonConfig] = []

const GRID_COLUMNS_DEFAULT := 5
const GRID_ROWS_DEFAULT    := 4

func _ready() -> void:
	var settings := ConfigManager.load_settings()
	_grid.set_columns(int(settings.get("grid_columns", GRID_COLUMNS_DEFAULT)))
	_grid.set_rows(int(settings.get("grid_rows", GRID_ROWS_DEFAULT)))
	var lc_hex: String = settings.get("grid_line_color", "")
	if not lc_hex.is_empty() and Color.html_is_valid(lc_hex):
		_grid.set_line_color(Color.html(lc_hex))
	_grid.button_moved.connect(_on_grid_button_moved)
	reload()

func set_columns(n: int) -> void:
	_grid.set_columns(n)

func set_rows(n: int) -> void:
	_grid.set_rows(n)

func set_line_color(c: Color) -> void:
	_grid.set_line_color(c)

func reload() -> void:
	_board = ConfigManager.load_board()
	_assign_missing_slots(_board)
	_rebuild_grid()

## Assign sequential slots to any config that still has slot = -1 (backward compat).
func _assign_missing_slots(configs: Array[ButtonConfig]) -> void:
	var used: Dictionary = {}
	for cfg in configs:
		if cfg.slot >= 0:
			used[cfg.slot] = true
	var needs_save := false
	for cfg in configs:
		if cfg.slot < 0:
			var s := 0
			while used.has(s):
				s += 1
			cfg.slot = s
			used[s] = true
			needs_save = true
	if needs_save:
		ConfigManager.save_board(configs)

func _rebuild_grid() -> void:
	_grid.clear_all()
	for btn_config in _board:
		_instantiate_button(btn_config)

func _instantiate_button(btn_config: ButtonConfig) -> void:
	if btn_config.type == "sound":
		var btn := _sound_button_scene.instantiate() as Button
		_grid.place_button(btn, btn_config.slot)
		btn.setup(btn_config)
		btn.right_clicked.connect(button_right_clicked.emit)
		btn.drag_drop_swap.connect(_on_drag_drop_swap)
	elif btn_config.type == "folder":
		var btn := _folder_button_scene.instantiate() as Button
		_grid.place_button(btn, btn_config.slot)
		btn.setup(btn_config)
		btn.right_clicked.connect(button_right_clicked.emit)
		btn.folder_opened.connect(folder_opened.emit)
		btn.drag_drop_swap.connect(_on_drag_drop_swap)

func _on_drag_drop_swap(from_id: String, to_id: String) -> void:
	var from_cfg := _find_recursive(_board, from_id)
	var to_cfg := _find_recursive(_board, to_id)
	if from_cfg == null or to_cfg == null:
		return
	var temp_slot := from_cfg.slot
	from_cfg.slot = to_cfg.slot
	to_cfg.slot = temp_slot
	ConfigManager.save_board(_board)
	_grid.swap_slots(from_id, to_id)

func _on_grid_button_moved(id: String, to_slot: int) -> void:
	var cfg := _find_recursive(_board, id)
	if cfg == null:
		return
	cfg.slot = to_slot
	ConfigManager.save_board(_board)
	_grid.move_to_slot(id, to_slot)

# --- Root-board operations ---

func add_button(btn_config: ButtonConfig) -> void:
	if btn_config.slot < 0:
		btn_config.slot = _grid.find_next_free_slot()
	_board.append(btn_config)
	ConfigManager.save_board(_board)
	_instantiate_button(btn_config)

func update_button(updated: ButtonConfig) -> void:
	_update_recursive(_board, updated)
	ConfigManager.save_board(_board)
	var widget := _find_widget(updated.id)
	if widget != null:
		widget.call("setup", updated)
	else:
		_rebuild_grid()

func delete_button(target: ButtonConfig) -> void:
	_delete_recursive(_board, target.id)
	ConfigManager.save_board(_board)
	_grid.remove_node_by_id(target.id)

# --- Folder (nested) operations ---

## Add a child button inside a folder identified by folder_id.
## Does NOT rebuild the main grid (folder content is not on the main board).
## Caller is responsible for refreshing the open folder panel if needed.
func add_to_folder(folder_id: String, child: ButtonConfig) -> void:
	var folder := _find_recursive(_board, folder_id)
	if folder == null:
		push_error("Soundboard: folder not found: " + folder_id)
		return
	folder.children.append(child)
	ConfigManager.save_board(_board)

## Update any button (root or nested) by ID. Rebuilds grid.
func update_in_tree(config: ButtonConfig) -> void:
	_update_recursive(_board, config)
	ConfigManager.save_board(_board)
	_rebuild_grid()

## Delete any button (root or nested) by ID. Rebuilds grid.
func delete_from_tree(config: ButtonConfig) -> void:
	_delete_recursive(_board, config.id)
	ConfigManager.save_board(_board)
	_rebuild_grid()

## Find a ButtonConfig anywhere in the tree by ID.
func find_in_board(id: String) -> ButtonConfig:
	return _find_recursive(_board, id)

func get_board() -> Array[ButtonConfig]:
	return _board

# --- Private helpers ---

func _find_widget(id: String) -> Node:
	for child in _grid.get_children():
		var cfg: Variant = child.get("config")
		if cfg is ButtonConfig and (cfg as ButtonConfig).id == id:
			return child
	return null

func _find_recursive(configs: Array[ButtonConfig], id: String) -> ButtonConfig:
	for cfg in configs:
		if cfg.id == id:
			return cfg
		if cfg.type == "folder" and not cfg.children.is_empty():
			var found := _find_recursive(cfg.children, id)
			if found != null:
				return found
	return null

func _update_recursive(configs: Array[ButtonConfig], target: ButtonConfig) -> bool:
	for i in range(configs.size()):
		if configs[i].id == target.id:
			configs[i] = target
			return true
		if configs[i].type == "folder":
			if _update_recursive(configs[i].children, target):
				return true
	return false

func _delete_recursive(configs: Array[ButtonConfig], target_id: String) -> bool:
	for i in range(configs.size()):
		if configs[i].id == target_id:
			configs.remove_at(i)
			return true
		if configs[i].type == "folder":
			if _delete_recursive(configs[i].children, target_id):
				return true
	return false
