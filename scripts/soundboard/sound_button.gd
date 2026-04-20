extends Button

signal right_clicked(config: ButtonConfig)
signal drag_drop_swap(from_id: String, to_id: String)

var config: ButtonConfig = null

@onready var _bg_rect: ColorRect           = $BGRect
@onready var _image_rect: TextureRect      = $ImageRect
@onready var _label: Label                 = $ButtonLabel
@onready var _playing_indicator: Label     = $PlayingIndicator
@onready var _missing_indicator: Label    = $MissingIndicator
@onready var _effect_overlay: ColorRect    = $EffectOverlay

var _base_color: Color = Color(0.2, 0.4, 0.8, 1.0)
var _effect_materials: Array[ShaderMaterial] = []
var _bg_clip_mats:  Array[ShaderMaterial] = []
var _img_clip_mats: Array[ShaderMaterial] = []

func _ready() -> void:
	var bg_shader  := load("res://shaders/shape_clip.gdshader")     as Shader
	var img_shader := load("res://shaders/shape_clip_tex.gdshader") as Shader
	for i in 4:
		var bg := ShaderMaterial.new()
		bg.shader = bg_shader
		bg.set_shader_parameter("shape_type", i)
		_bg_clip_mats.append(bg)
		var img := ShaderMaterial.new()
		img.shader = img_shader
		img.set_shader_parameter("shape_type", i)
		_img_clip_mats.append(img)
	for shader_path in [
		"res://shaders/effect_plasma.gdshader",
		"res://shaders/effect_fire.gdshader",
		"res://shaders/effect_glitch.gdshader",
		"res://shaders/effect_ripple.gdshader",
	]:
		var mat := ShaderMaterial.new()
		mat.shader = load(shader_path)
		_effect_materials.append(mat)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_playing_indicator.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	_missing_indicator.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	AudioService.playback_started.connect(_on_playback_started)
	AudioService.playback_stopped.connect(_on_playback_stopped)
	AudioService.playback_repeated.connect(_on_playback_repeated)
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	button_down.connect(_on_press_start)
	button_up.connect(_on_press_end)

func _exit_tree() -> void:
	AudioService.playback_started.disconnect(_on_playback_started)
	AudioService.playback_stopped.disconnect(_on_playback_stopped)
	AudioService.playback_repeated.disconnect(_on_playback_repeated)

func setup(btn_config: ButtonConfig) -> void:
	config = btn_config
	_label.text = btn_config.label
	_base_color = btn_config.color
	_bg_rect.color = _base_color
	_load_image(btn_config.image)
	var wav_missing := not btn_config.wav.is_empty() and not FileAccess.file_exists(btn_config.wav)
	_missing_indicator.visible = wav_missing
	var si := _shape_index(btn_config.shape)
	_bg_rect.material   = _bg_clip_mats[si]
	_image_rect.material = _img_clip_mats[si]

func _shape_index(shape: String) -> int:
	match shape:
		"circle": return 1
		"star":   return 2
		"heart":  return 3
		_:        return 0

func _has_point(point: Vector2) -> bool:
	var sz := get_size()
	var c  := sz / 2.0
	match config.shape if config != null else "square":
		"circle":
			return (point - c).length() <= minf(sz.x, sz.y) / 2.0
		"star":
			var r: float = minf(sz.x, sz.y) / 2.0
			var p: Vector2 = (point - c) / r
			p.y = -p.y
			return _sdf_star5(p, 0.95, 0.45) >= 0.0
		"heart":
			var r: float = minf(sz.x, sz.y) / 2.0
			var p: Vector2 = (point - c) / r
			p.y = -p.y
			p *= 1.25
			p.y += 0.115
			var a: float = p.dot(p) - 1.0
			return a * a * a - p.x * p.x * p.y * p.y * p.y <= 0.0
		_:
			return Rect2(Vector2.ZERO, sz).has_point(point)

func _sdf_star5(p: Vector2, r: float, rf: float) -> float:
	var k1 := Vector2(0.809016994375, -0.587785252192)
	var k2 := Vector2(-0.809016994375, -0.587785252192)
	p.x = abs(p.x)
	p -= 2.0 * max(k1.dot(p), 0.0) * k1
	p -= 2.0 * max(k2.dot(p), 0.0) * k2
	p.x = abs(p.x)
	p.y -= r
	var ba := rf * Vector2(-k1.y, k1.x) - Vector2(0.0, 1.0)
	var h  := clampf(p.dot(ba) / ba.dot(ba), 0.0, r)
	return (p - ba * h).length() * signf(p.x * ba.y - p.y * ba.x)

func _on_playback_started(path: String) -> void:
	if config != null and config.wav == path:
		match config.repeat_mode:
			"infinite": _playing_indicator.text = "∞"
			"count":    _playing_indicator.text = "×%d" % config.repeat_count
			_:          _playing_indicator.text = "▶"
		var eff_idx: int
		match config.effect:
			"plasma": eff_idx = 0
			"fire":   eff_idx = 1
			"glitch": eff_idx = 2
			"ripple": eff_idx = 3
			_:        eff_idx = randi() % _effect_materials.size()
		var eff_mat := _effect_materials[eff_idx]
		eff_mat.set_shader_parameter("shape_type", _shape_index(config.shape))
		_effect_overlay.material = eff_mat
		_playing_indicator.show()
		_effect_overlay.show()

func _on_playback_repeated(path: String, plays_remaining: int) -> void:
	if config != null and config.wav == path:
		_playing_indicator.text = "×%d" % plays_remaining

func _on_playback_stopped(path: String) -> void:
	if config != null and config.wav == path:
		_playing_indicator.hide()
		_effect_overlay.hide()

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
	if config == null or config.wav.is_empty():
		return
	if not FileAccess.file_exists(config.wav):
		_missing_indicator.show()
		return
	AudioService.toggle(config.wav, config.repeat_mode, config.repeat_count)

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
