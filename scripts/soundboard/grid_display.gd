class_name GridDisplay
extends Control

signal button_moved(id: String, to_slot: int)

const CELL_SIZE := 120

var columns: int = 5
var rows: int = 4
var line_color: Color = Color(0.0, 0.0, 0.0, 0.0)

# slot (int) → Control node
var _slot_map: Dictionary = {}

# Transparent overlay added as last child so its _draw runs on top of buttons
var _overlay: Control = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_on_overlay_draw)
	add_child(_overlay)

## Called when the overlay redraws — draws grid lines on top of all buttons.
func _on_overlay_draw() -> void:
	if line_color.a < 0.001:
		return
	var sz := custom_minimum_size
	var w := sz.x
	var h := sz.y
	for c in range(1, columns):
		var x := float(c * CELL_SIZE)
		_overlay.draw_line(Vector2(x, 0.0), Vector2(x, h), line_color)
	#NIFI var rows := int(h / float(CELL_SIZE))
	for r in range(1, rows):
		var y := float(r * CELL_SIZE)
		_overlay.draw_line(Vector2(0.0, y), Vector2(w, y), line_color)

# ── Public API ────────────────────────────────────────────────────────────────

func set_columns(n: int) -> void:
	columns = n
	_reposition_all()
	_update_min_size()
	_redraw_overlay()

func set_rows(n: int) -> void:
	rows = n
	_update_min_size()
	_redraw_overlay()

func set_line_color(c: Color) -> void:
	line_color = c
	_redraw_overlay()

func clear_all() -> void:
	for child in get_children():
		if child == _overlay:
			continue
		remove_child(child)
		child.queue_free()
	_slot_map.clear()
	_update_min_size()
	_redraw_overlay()

## Add node to the grid at the given slot and set its position + size.
func place_button(node: Control, slot: int) -> void:
	_slot_map[slot] = node
	node.position = _slot_to_pos(slot)
	node.size = Vector2(CELL_SIZE, CELL_SIZE)
	if node.get_parent() != self:
		add_child(node)
	# Keep overlay as the last child so it renders on top of every button.
	if _overlay != null:
		move_child(_overlay, get_child_count() - 1)
	_update_min_size()
	_redraw_overlay()

## Return the first free slot (lowest index not in use).
func find_next_free_slot() -> int:
	var s := 0
	while _slot_map.has(s):
		s += 1
	return s

## Swap the visual positions of two buttons by ID, without saving.
func swap_slots(id_a: String, id_b: String) -> void:
	var node_a := _find_node_by_id(id_a)
	var node_b := _find_node_by_id(id_b)
	if node_a == null or node_b == null:
		return
	var slot_a := _find_slot_of(node_a)
	var slot_b := _find_slot_of(node_b)
	if slot_a < 0 or slot_b < 0:
		return
	_slot_map[slot_a] = node_b
	_slot_map[slot_b] = node_a
	node_a.position = _slot_to_pos(slot_b)
	node_b.position = _slot_to_pos(slot_a)
	_update_min_size()
	_redraw_overlay()

## Move a button by ID to a new slot, without saving.
func move_to_slot(id: String, to_slot: int) -> void:
	var node := _find_node_by_id(id)
	if node == null:
		return
	var old_slot := _find_slot_of(node)
	if old_slot >= 0:
		_slot_map.erase(old_slot)
	_slot_map[to_slot] = node
	node.position = _slot_to_pos(to_slot)
	_update_min_size()
	_redraw_overlay()

## Remove a button by ID from the grid and free it.
func remove_node_by_id(id: String) -> void:
	var node := _find_node_by_id(id)
	if node == null:
		return
	var slot := _find_slot_of(node)
	if slot >= 0:
		_slot_map.erase(slot)
	remove_child(node)
	node.queue_free()
	_update_min_size()
	_redraw_overlay()

# ── Private helpers ───────────────────────────────────────────────────────────

func _find_node_by_id(id: String) -> Control:
	for s in _slot_map:
		var n: Control = _slot_map[s]
		var cfg: Variant = n.get("config")
		if cfg is ButtonConfig and (cfg as ButtonConfig).id == id:
			return n
	return null

func _find_slot_of(node: Control) -> int:
	for s in _slot_map:
		if _slot_map[s] == node:
			return int(s)
	return -1

func _slot_to_pos(slot: int) -> Vector2:
	@warning_ignore("integer_division")
	return Vector2((slot % columns) * CELL_SIZE, (slot / columns) * CELL_SIZE)

func _pos_to_slot(pos: Vector2) -> int:
	var col := int(pos.x / CELL_SIZE)
	var row := int(pos.y / CELL_SIZE)
	if col < 0 or col >= columns or row < 0:
		return -1
	return row * columns + col

func _reposition_all() -> void:
	for s in _slot_map:
		var node: Control = _slot_map[s]
		node.position = _slot_to_pos(int(s))

func _update_min_size() -> void:
	var max_slot := 0
	for s in _slot_map:
		if int(s) > max_slot:
			max_slot = int(s)
	# Show at least `rows` rows, but extend if buttons overflow below that.
	@warning_ignore("integer_division")
	var occupied_rows := max_slot / columns + 1
	var visible_rows := maxi(rows, occupied_rows)
	custom_minimum_size = Vector2(columns * CELL_SIZE, visible_rows * CELL_SIZE)

func _redraw_overlay() -> void:
	if _overlay != null:
		_overlay.queue_redraw()

# ── Drag-and-drop (empty cell targets) ───────────────────────────────────────

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var slot := _pos_to_slot(at)
	return slot >= 0 and not _slot_map.has(slot)

func _drop_data(at: Vector2, data: Variant) -> void:
	var slot := _pos_to_slot(at)
	if slot < 0 or _slot_map.has(slot):
		return
	var id: String = (data as Dictionary).get("id", "")
	if not id.is_empty():
		button_moved.emit(id, slot)
