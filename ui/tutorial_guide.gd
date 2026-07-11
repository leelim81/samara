class_name TutorialGuide
extends CanvasLayer
# Guided first-battle tutorial: a step-driven callout riding over the live
# board, with a pulsing gold ring marking WHERE to look and short text saying
# WHAT to do. Each step advances when the player actually performs the action
# (drag, pincer, chain, timer); tapping the callout also advances, and Skip
# ends the whole tour. Completing or skipping sets SaveData.tutorial_seen, so
# the guide runs exactly once, in the first battle a new player enters.
#
# Purely observational: it never pauses the game, blocks input to the board,
# or changes battle logic.

const _RING_TEXTURE := preload("res://assets/vfx/soft_ring.png")
const _RING_SIZE := 132.0
const _GOLD := Color(0.753, 0.627, 0.384)

var _board: Node = null
var _battle: Node = null

var _step: int = -1
var _steps: Array = []
var _pending_signal: Array = []  # [object, signal_name] currently connected

var _root: Control
var _ring: TextureRect
var _panel: Button
var _text_label: Label
var _hint_label: Label
var _target: Callable = Callable()


static func should_run() -> bool:
	return GameData.save_data != null and not GameData.save_data.tutorial_seen


func setup(board: Node, battle: Node) -> void:
	_board = board
	_battle = battle


func _ready() -> void:
	layer = 90

	_build_ui()

	_steps = [
		{
			"text": "TUT_MOVE",
			"target": func(): return _unit_position(_alive(_board._player_units_node), 0),
			"advance": [_board, "drag_timer_started"],
		},
		{
			"text": "TUT_PINCER",
			"target": func(): return _unit_position(_alive(_board._enemy_units_node), 0),
			"advance": [Events, "cutin_requested"],
		},
		{
			"text": "TUT_CHAIN",
			"target": func(): return _unit_position(_alive(_board._player_units_node), 2),
			"advance": [Events, "cutin_requested"],
		},
		{
			"text": "TUT_TIMER",
			"target": func(): return _timer_bar_position(),
			"advance": [_board, "drag_timer_stopped"],
		},
		{
			"text": "TUT_READY",
			"target": Callable(),
			"advance": [],
		},
	]

	_enter_step(0)


func _process(_delta: float) -> void:
	if not _target.is_valid():
		_ring.visible = false
		return

	var pos = _target.call()

	if pos == null:
		_ring.visible = false
		return

	_ring.visible = true
	_ring.position = (pos as Vector2) - _ring.size * 0.5


# ---- steps ------------------------------------------------------------------

func _enter_step(index: int) -> void:
	_disconnect_pending()

	if index >= _steps.size():
		_finish()
		return

	_step = index

	var step: Dictionary = _steps[index]

	_text_label.text = tr(step.text)
	_target = step.target

	if step.advance.is_empty():
		# Final beat: linger, then bow out on its own.
		_hint_label.text = ""
		get_tree().create_timer(2.6).timeout.connect(_finish, CONNECT_ONE_SHOT)
	else:
		_hint_label.text = tr("TUT_CONTINUE")
		var emitter: Object = step.advance[0]
		var signal_name: String = step.advance[1]
		emitter.connect(signal_name, _on_step_action)
		_pending_signal = [emitter, signal_name]

	# A soft re-entrance so each step visibly changes.
	_panel.modulate.a = 0.35
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.22)


# Signal signatures vary (0..5 args); swallow whatever arrives.
func _on_step_action(_a = null, _b = null, _c = null, _d = null, _e = null) -> void:
	_advance()


func _advance() -> void:
	if _step >= 0:
		_enter_step(_step + 1)


func _disconnect_pending() -> void:
	if _pending_signal.size() == 2:
		var emitter: Object = _pending_signal[0]
		var signal_name: String = _pending_signal[1]

		if is_instance_valid(emitter) and emitter.is_connected(signal_name, _on_step_action):
			emitter.disconnect(signal_name, _on_step_action)

	_pending_signal = []


func _finish() -> void:
	if _step < 0:
		return

	_step = -1
	_disconnect_pending()
	_target = Callable()

	if GameData.save_data != null and not GameData.save_data.tutorial_seen:
		GameData.save_data.tutorial_seen = true
		GameData.save()

	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


# ---- targets ----------------------------------------------------------------

func _alive(units_node: Node) -> Array:
	var alive := []

	for unit in units_node.get_children():
		if unit.is_alive():
			alive.push_back(unit)

	return alive


# Screen position of the unit at `index` (clamped), or null when none remain.
func _unit_position(units: Array, index: int):
	if units.is_empty():
		return null

	var unit = units[clampi(index, 0, units.size() - 1)]

	return unit.get_global_transform_with_canvas().origin


func _timer_bar_position():
	var bar: Control = _battle.get_node_or_null("CanvasLayer/MarginContainer/Hud/Row2/C1/TimerRow/TimerBar")

	return bar.get_global_rect().get_center() if bar != null else null


# ---- construction -----------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# The pulsing look-here ring.
	_ring = TextureRect.new()
	_ring.texture = _RING_TEXTURE
	_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ring.size = Vector2(_RING_SIZE, _RING_SIZE)
	_ring.pivot_offset = _ring.size * 0.5
	_ring.modulate = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.9)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.visible = false
	_root.add_child(_ring)

	var pulse := create_tween().set_loops()
	pulse.tween_property(_ring, "scale", Vector2(1.18, 1.18), 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.parallel().tween_property(_ring, "modulate:a", 0.45, 0.55)
	pulse.tween_property(_ring, "scale", Vector2(0.92, 0.92), 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.parallel().tween_property(_ring, "modulate:a", 0.9, 0.55)

	# The callout: an ink plate near the bottom. The whole plate is a button
	# (tap to continue); children ignore the mouse so clicks reach it.
	_panel = Button.new()
	_panel.flat = true
	_panel.focus_mode = Control.FOCUS_NONE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.086, 0.106, 0.94)
	style.border_color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.8)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("normal", style)
	_panel.add_theme_stylebox_override("hover", style)
	_panel.add_theme_stylebox_override("pressed", style)
	_panel.add_theme_stylebox_override("focus", style)

	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = 46
	_panel.offset_right = -46
	_panel.offset_bottom = -18
	_panel.pressed.connect(_advance)
	_root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 14
	vbox.offset_right = -14
	vbox.offset_top = 12
	vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 18)
	_text_label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_text_label)

	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom_row)

	_hint_label = Label.new()
	_hint_label.text = tr("TUT_CONTINUE")
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.56, 0.63, 0.74))
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(_hint_label)

	var skip := Button.new()
	skip.text = tr("TUT_SKIP")
	skip.flat = true
	skip.add_theme_font_size_override("font_size", 13)
	skip.add_theme_color_override("font_color", Color(_GOLD.r, _GOLD.g, _GOLD.b))
	skip.pressed.connect(_finish)
	bottom_row.add_child(skip)