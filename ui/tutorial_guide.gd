class_name TutorialGuide
extends CanvasLayer
# Strict guided first-battle tutorial. Over the live board it dims everything
# except a single spotlit unit (or the timer), pulses a gold ring on it, and
# shows a short callout of what to do. While a step is active ONLY the spotlit
# unit accepts input (Events.tutorial_locked_unit), so a new player literally
# cannot do anything except the one action being taught. Each step advances
# when the player performs that action; a Skip button ends the tour.
#
# It never pauses the game or changes battle logic: the dimming overlay ignores
# the mouse (clicks pass through to the allowed unit) and the input gate is
# enforced at the unit level.

const _RING_TEXTURE := preload("res://assets/vfx/soft_ring.png")
const _RING_SIZE := 150.0
const _GOLD := Color(0.83, 0.68, 0.36)
const _DIM := Color(0.03, 0.035, 0.05, 0.72)
const _HOLE_PAD := 58.0

var _board: Node = null
var _battle: Node = null

var _step: int = -1
var _steps: Array = []
var _pending_signal: Array = []  # [object, signal_name] currently connected

var _rect_fn: Callable = Callable()   # current step's spotlight rect (screen)
var _lock_fn: Callable = Callable()   # current step's locked unit

# Scripted layout: the hero the player must drag, and the tile to drop on.
var _drag_unit: Node = null
var _target_coords: Vector2 = Vector2(-1, -1)
var _target_coords_current: Vector2 = Vector2(-1, -1)  # the active step's target
var _tap_advances: bool = false                        # only true on tap steps

var _root: Control
var _ring: TextureRect
var _target_marker: TextureRect
var _mask_top: ColorRect
var _mask_bottom: ColorRect
var _mask_left: ColorRect
var _mask_right: ColorRect
var _frame: Panel
var _panel: Button
var _text_label: Label
var _hint_label: Label
var _arrow: Label


static func should_run() -> bool:
	return GameData.save_data != null and not GameData.save_data.tutorial_seen


func setup(board: Node, battle: Node) -> void:
	_board = board
	_battle = battle


func _ready() -> void:
	layer = 90

	_build_ui()

	# Let the board finish placing every unit on its cell before rearranging.
	await get_tree().process_frame

	var forced: bool = _setup_layout()

	if forced:
		# On-rails: one forced drag onto a marked tile forms a pincer, then a
		# short explanation, then free play.
		_steps = [
			{
				"text": "TUT_DRAG_HERE",
				"lock": func(): return _drag_unit,
				"target": _target_coords,
				"advance": [Events, "cutin_requested"],
			},
			{
				"text": "TUT_PINCER_DONE",
				"advance": "tap",
			},
			{
				"text": "TUT_FINISH",
				"advance": [],
			},
		]
	else:
		# Fallback (unexpected squad shape): guide without forcing a cell.
		_steps = [
			{
				"text": "TUT_DRAG_HERE",
				"lock": func(): return _player(0),
				"advance": [Events, "cutin_requested"],
			},
			{
				"text": "TUT_FINISH",
				"advance": [],
			},
		]

	_enter_step(0)


func _process(_delta: float) -> void:
	# The bright "drop here" marker follows the target tile.
	var marker_pos = _target_cell_screen_pos()
	if marker_pos == null:
		_target_marker.visible = false
	else:
		_target_marker.visible = true
		_target_marker.position = (marker_pos as Vector2) - _target_marker.size * 0.5

	var rect = _current_rect()

	if rect == null:
		_set_spotlight_visible(false)
		return

	_set_spotlight_visible(true)
	_layout_spotlight(rect as Rect2)


# ---- scripted layout --------------------------------------------------------

# Rearranges the board into a fixed layout where one forced drag onto a marked
# tile forms a pincer. Returns false (no forcing) if the squad shape is
# unexpected, so the guide degrades gracefully instead of breaking.
func _setup_layout() -> bool:
	var grid = _board.get_node_or_null("Grid")
	if grid == null:
		return false

	var players := _alive(_board._player_units_node)
	var enemies := _alive(_board._enemy_units_node)

	if players.size() < 2 or enemies.is_empty():
		return false

	# Vacate every unit's current cell first so placements never collide.
	for u in players + enemies:
		var c = grid.get_cell_from_position(u.position)
		if c != null and c.unit == u:
			c.unit = null

	# A row of partner + enemy + (drop target); the draggable hero sits below
	# the target so a straight drag up completes the pincer.
	_place(grid, players[1], Vector2(2, 3))   # partner holds one side
	_place(grid, enemies[0], Vector2(3, 3))   # enemy to trap
	_place(grid, players[0], Vector2(4, 5))   # the hero the player drags
	_drag_unit = players[0]
	_target_coords = Vector2(4, 3)

	# Park any extra units out of the way.
	var spare := [Vector2(0, 7), Vector2(1, 7), Vector2(0, 6), Vector2(1, 6)]
	for i in range(2, players.size()):
		if i - 2 < spare.size():
			_place(grid, players[i], spare[i - 2])

	var espare := [Vector2(5, 0), Vector2(4, 0), Vector2(5, 1), Vector2(4, 1)]
	for i in range(1, enemies.size()):
		if i - 1 < espare.size():
			_place(grid, enemies[i], espare[i - 1])

	return true


func _place(grid, unit, coords: Vector2) -> void:
	var cell = grid.get_cell_from_coordinates(coords)
	if cell == null:
		return
	cell.unit = unit
	unit.position = cell.position


# Screen-space center of the current step's target tile, or null when none.
func _target_cell_screen_pos():
	if _target_coords_current.x < 0.0:
		return null

	var grid = _board.get_node_or_null("Grid")
	if grid == null:
		return null

	var cell = grid.get_cell_from_coordinates(_target_coords_current)
	if cell == null:
		return null

	return cell.get_global_transform_with_canvas().origin


# ---- steps ------------------------------------------------------------------

func _enter_step(index: int) -> void:
	_disconnect_pending()

	if index >= _steps.size():
		_finish()
		return

	_step = index

	var step: Dictionary = _steps[index]

	_text_label.text = tr(step.text)
	_rect_fn = step.get("rect", Callable())
	_lock_fn = step.get("lock", Callable())

	# Gate all board input to the step's unit (if any).
	Events.tutorial_locked_unit = _locked_unit()

	# Gate the drop destination (the forced move). Setting real coordinates
	# makes the board reject any drop but the marked cell.
	_target_coords_current = step.get("target", Vector2(-1, -1))
	Events.tutorial_required_coords = _target_coords_current

	# Only explanation ("tap") steps advance when the callout is tapped; forced
	# steps must be completed by the taught action.
	var advance = step.advance
	_tap_advances = advance is String and advance == "tap"

	if advance is String:
		# Tap-to-continue explanation step.
		_hint_label.text = tr("TUT_CONTINUE")
	elif advance.is_empty():
		# Final beat: no lock, no spotlight; linger then bow out.
		Events.tutorial_locked_unit = null
		Events.tutorial_required_coords = Vector2(-1, -1)
		_hint_label.text = ""
		get_tree().create_timer(2.6).timeout.connect(_finish, CONNECT_ONE_SHOT)
	else:
		_hint_label.text = ""
		var emitter: Object = advance[0]
		var signal_name: String = advance[1]
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
	_rect_fn = Callable()
	_lock_fn = Callable()
	_target_coords_current = Vector2(-1, -1)

	# Always release both gates when the tutorial ends.
	Events.tutorial_locked_unit = null
	Events.tutorial_required_coords = Vector2(-1, -1)

	if GameData.save_data != null and not GameData.save_data.tutorial_seen:
		GameData.save_data.tutorial_seen = true
		GameData.save()

	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _notification(what: int) -> void:
	# Never leave the board gated if the guide is torn down unexpectedly.
	if what == NOTIFICATION_PREDELETE:
		Events.tutorial_locked_unit = null
		Events.tutorial_required_coords = Vector2(-1, -1)


# Tapping the callout only advances explanation steps; forced steps must be
# completed by the taught action (the Skip button remains the escape hatch).
func _on_callout_tapped() -> void:
	if _tap_advances:
		_advance()


# ---- focus / targets --------------------------------------------------------

func _locked_unit():
	if _lock_fn.is_valid():
		return _lock_fn.call()
	return null


# The spotlight rect: an explicit rect if the step provides one, else the
# locked unit's rect, else null (no spotlight).
func _current_rect():
	if _rect_fn.is_valid():
		return _rect_fn.call()

	var unit = _locked_unit()
	if unit != null and is_instance_valid(unit):
		return _unit_rect(unit)

	return null


func _player(index: int):
	return _nth_alive(_board._player_units_node, index)


func _nth_alive(units_node: Node, index: int):
	var alive: Array = _alive(units_node)
	if alive.is_empty():
		return null
	return alive[clampi(index, 0, alive.size() - 1)]


func _alive(units_node: Node) -> Array:
	var alive := []
	for unit in units_node.get_children():
		if unit.is_alive():
			alive.push_back(unit)
	return alive


func _unit_rect(unit) -> Rect2:
	var c: Vector2 = unit.get_global_transform_with_canvas().origin
	var half := Vector2(_HOLE_PAD, _HOLE_PAD)
	return Rect2(c - half, half * 2.0)


func _timer_rect():
	var bar: Control = _battle.get_node_or_null("CanvasLayer/MarginContainer/Hud/Row2/C1/TimerRow/TimerBar")
	if bar == null:
		return null
	var r := bar.get_global_rect()
	return r.grow(10.0)


# ---- spotlight layout -------------------------------------------------------

func _set_spotlight_visible(v: bool) -> void:
	_mask_top.visible = v
	_mask_bottom.visible = v
	_mask_left.visible = v
	_mask_right.visible = v
	_frame.visible = v
	_ring.visible = v


# Frame the hole with four dark quads (everything outside the hole is dimmed),
# a gold outline around it, and the pulsing ring centered on it.
func _layout_spotlight(hole: Rect2) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size

	var x0: float = clampf(hole.position.x, 0.0, screen.x)
	var y0: float = clampf(hole.position.y, 0.0, screen.y)
	var x1: float = clampf(hole.position.x + hole.size.x, 0.0, screen.x)
	var y1: float = clampf(hole.position.y + hole.size.y, 0.0, screen.y)

	_mask_top.position = Vector2.ZERO
	_mask_top.size = Vector2(screen.x, y0)

	_mask_bottom.position = Vector2(0, y1)
	_mask_bottom.size = Vector2(screen.x, screen.y - y1)

	_mask_left.position = Vector2(0, y0)
	_mask_left.size = Vector2(x0, y1 - y0)

	_mask_right.position = Vector2(x1, y0)
	_mask_right.size = Vector2(screen.x - x1, y1 - y0)

	_frame.position = Vector2(x0, y0)
	_frame.size = Vector2(x1 - x0, y1 - y0)

	var center := Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
	_ring.position = center - _ring.size * 0.5


# ---- construction -----------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Four dark quads that dim everything outside the spotlight hole. They
	# ignore the mouse, so clicks still reach the allowed unit underneath.
	_mask_top = _make_dim()
	_mask_bottom = _make_dim()
	_mask_left = _make_dim()
	_mask_right = _make_dim()

	# Gold outline framing the hole.
	_frame = Panel.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color(0, 0, 0, 0)
	fstyle.border_color = _GOLD
	fstyle.set_border_width_all(2)
	fstyle.set_corner_radius_all(10)
	_frame.add_theme_stylebox_override("panel", fstyle)
	_root.add_child(_frame)

	# The pulsing look-here ring.
	_ring = TextureRect.new()
	_ring.texture = _RING_TEXTURE
	_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ring.size = Vector2(_RING_SIZE, _RING_SIZE)
	_ring.pivot_offset = _ring.size * 0.5
	_ring.modulate = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.9)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ring)

	var pulse := create_tween().set_loops()
	pulse.tween_property(_ring, "scale", Vector2(1.16, 1.16), 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.parallel().tween_property(_ring, "modulate:a", 0.5, 0.6)
	pulse.tween_property(_ring, "scale", Vector2(0.94, 0.94), 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.parallel().tween_property(_ring, "modulate:a", 0.9, 0.6)

	# The bright "drop here" marker on the target tile. It rides ON TOP of the
	# dimming, so it reads even though the target cell is itself dimmed.
	_target_marker = TextureRect.new()
	_target_marker.texture = _RING_TEXTURE
	_target_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_marker.size = Vector2(104, 104)
	_target_marker.pivot_offset = _target_marker.size * 0.5
	_target_marker.modulate = Color(1.0, 0.9, 0.5, 1.0)
	_target_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_marker.visible = false
	_root.add_child(_target_marker)

	var mpulse := create_tween().set_loops()
	mpulse.tween_property(_target_marker, "scale", Vector2(1.14, 1.14), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mpulse.parallel().tween_property(_target_marker, "modulate:a", 0.55, 0.5)
	mpulse.tween_property(_target_marker, "scale", Vector2(0.9, 0.9), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mpulse.parallel().tween_property(_target_marker, "modulate:a", 1.0, 0.5)

	_build_callout()

	_set_spotlight_visible(false)


func _make_dim() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = _DIM
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	return rect


func _build_callout() -> void:
	# The callout: an ink plate near the bottom. The whole plate is a button
	# (tap to continue); children ignore the mouse so clicks reach it. A Button
	# does not grow to fit Control children, so it is sized and placed
	# explicitly to always sit fully on-screen (text was overflowing before).
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var margin := 36.0
	var panel_h := 132.0

	_panel = Button.new()
	_panel.flat = true
	_panel.focus_mode = Control.FOCUS_NONE
	_panel.clip_contents = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.086, 0.106, 0.97)
	style.border_color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("normal", style)
	_panel.add_theme_stylebox_override("hover", style)
	_panel.add_theme_stylebox_override("pressed", style)
	_panel.add_theme_stylebox_override("focus", style)

	_panel.position = Vector2(margin, screen.y - panel_h - margin)
	_panel.size = Vector2(screen.x - margin * 2.0, panel_h)
	_panel.pressed.connect(_on_callout_tapped)
	_root.add_child(_panel)

	# Message pinned to the top of the plate, wrapping within its width.
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 18)
	_text_label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.position = Vector2(16, 14)
	_text_label.size = Vector2(_panel.size.x - 32, panel_h - 50)
	_panel.add_child(_text_label)

	# Hint + Skip pinned to the bottom of the plate, so they are never clipped.
	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.position = Vector2(16, panel_h - 30)
	bottom_row.size = Vector2(_panel.size.x - 32, 22)
	_panel.add_child(bottom_row)

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
