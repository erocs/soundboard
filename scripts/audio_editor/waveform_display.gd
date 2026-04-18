class_name WaveformDisplay
extends Control

## Emitted while the user drags an in/out trim marker.
signal trim_changed(in_frame: int, out_frame: int)

const GRAB_PX      := 8.0
const COLOR_BG     := Color(0.07, 0.07, 0.10)
const COLOR_WAVE   := Color(0.35, 0.65, 1.00)
const COLOR_DIMMED := Color(0.15, 0.28, 0.45)
const COLOR_MASK   := Color(0.00, 0.00, 0.00, 0.52)
const COLOR_IN     := Color(0.20, 1.00, 0.40)
const COLOR_OUT    := Color(1.00, 0.28, 0.28)
const COLOR_HEAD   := Color(1.00, 0.90, 0.20)

## When true, mouse interaction and trim markers are disabled (preview mode).
var read_only: bool = false

var _samples: PackedFloat32Array = []
var _peaks_lo: PackedFloat32Array = []
var _peaks_hi: PackedFloat32Array = []
var _in_frame: int = 0
var _out_frame: int = 0
var _playhead_frame: int = -1
var _drag: String = ""  # "" | "in" | "out"

# ── Public API ────────────────────────────────────────────────────────────

func load_samples(pcm: PackedFloat32Array, in_frame: int, out_frame: int) -> void:
	_samples = pcm
	_in_frame = in_frame
	_out_frame = out_frame
	_playhead_frame = -1
	_build_peaks()
	queue_redraw()

func set_playhead(frame: int) -> void:
	_playhead_frame = frame
	queue_redraw()

func get_in_frame() -> int:
	return _in_frame

func get_out_frame() -> int:
	return _out_frame

# ── Drawing ───────────────────────────────────────────────────────────────

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), COLOR_BG)
	if _peaks_lo.is_empty() or w <= 0 or h <= 0:
		return

	var mid := h * 0.5
	var n := _peaks_lo.size()
	var in_x  := _frame_to_x(_in_frame)
	var out_x := _frame_to_x(_out_frame)

	# Waveform bars
	for xi in range(n):
		var px := xi * w / float(n)
		var lo := _peaks_lo[xi]
		var hi := _peaks_hi[xi]
		var col := COLOR_WAVE if (px >= in_x and px <= out_x) else COLOR_DIMMED
		draw_line(Vector2(px, mid - hi * mid), Vector2(px, mid - lo * mid), col)

	# Dim regions outside trim selection
	if in_x > 0:
		draw_rect(Rect2(0, 0, in_x, h), COLOR_MASK)
	if out_x < w:
		draw_rect(Rect2(out_x, 0, w - out_x, h), COLOR_MASK)

	# Trim marker lines + small top handles (hidden in read-only/preview mode)
	if not read_only:
		draw_line(Vector2(in_x, 0), Vector2(in_x, h), COLOR_IN, 2.0)
		draw_colored_polygon(
			PackedVector2Array([Vector2(in_x, 0), Vector2(in_x - 7, 0), Vector2(in_x, 12)]),
			COLOR_IN)

		draw_line(Vector2(out_x, 0), Vector2(out_x, h), COLOR_OUT, 2.0)
		draw_colored_polygon(
			PackedVector2Array([Vector2(out_x, 0), Vector2(out_x + 7, 0), Vector2(out_x, 12)]),
			COLOR_OUT)

	# Playhead
	if _playhead_frame >= 0:
		var ph := _frame_to_x(_playhead_frame)
		draw_line(Vector2(ph, 0), Vector2(ph, h), COLOR_HEAD, 1.5)

# ── Mouse interaction ─────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if read_only:
		return
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT:
			if mbe.pressed:
				var in_x  := _frame_to_x(_in_frame)
				var out_x := _frame_to_x(_out_frame)
				if abs(mbe.position.x - in_x) <= GRAB_PX:
					_drag = "in"
					accept_event()
				elif abs(mbe.position.x - out_x) <= GRAB_PX:
					_drag = "out"
					accept_event()
			else:
				_drag = ""

	elif event is InputEventMouseMotion:
		_update_cursor(event.position.x)
		if _drag == "in":
			_in_frame = mini(_x_to_frame(event.position.x), _out_frame - 1)
			trim_changed.emit(_in_frame, _out_frame)
			queue_redraw()
			accept_event()
		elif _drag == "out":
			_out_frame = maxi(_x_to_frame(event.position.x), _in_frame + 1)
			trim_changed.emit(_in_frame, _out_frame)
			queue_redraw()
			accept_event()

func _update_cursor(mouse_x: float) -> void:
	if read_only:
		mouse_default_cursor_shape = CURSOR_ARROW
		return
	var near_in  := absf(mouse_x - _frame_to_x(_in_frame))  <= GRAB_PX
	var near_out := absf(mouse_x - _frame_to_x(_out_frame)) <= GRAB_PX
	mouse_default_cursor_shape = CURSOR_HSIZE if (near_in or near_out) else CURSOR_ARROW

# ── Helpers ───────────────────────────────────────────────────────────────

func _frame_to_x(frame: int) -> float:
	if _samples.is_empty():
		return 0.0
	return float(frame) / float(_samples.size()) * size.x

func _x_to_frame(x: float) -> int:
	if _samples.is_empty():
		return 0
	return clampi(int(x / size.x * float(_samples.size())), 0, _samples.size())

func _build_peaks() -> void:
	_peaks_lo.clear()
	_peaks_hi.clear()
	if _samples.is_empty():
		return
	var n: int = int(size.x) if size.x >= 4.0 else 512
	_peaks_lo.resize(n)
	_peaks_hi.resize(n)
	var spx := float(_samples.size()) / float(n)
	for xi in range(n):
		var s := int(xi * spx)
		var e := mini(int((xi + 1) * spx), _samples.size() - 1)
		var lo := _samples[s]
		var hi := _samples[s]
		for i in range(s + 1, e + 1):
			var v := _samples[i]
			if v < lo: lo = v
			if v > hi: hi = v
		_peaks_lo[xi] = lo
		_peaks_hi[xi] = hi

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _samples.is_empty():
		_build_peaks()
		queue_redraw()
