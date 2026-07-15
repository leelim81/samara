class_name TutorialGuide
extends CanvasLayer
# Scripted, on-rails first-battle tutorial. It rearranges the board into a
# fixed layout and walks the player through two forced moves the Terra Battle
# way: a pincer, then a chain. During a move only the marked hero accepts
# input (Events.tutorial_locked_unit) and only the marked tile accepts the drop
# (Events.tutorial_required_coords, enforced by the board) so the ONLY possible
# action is the one being taught. A wrong drop snaps the hero back.
#
# The board is dimmed except the hero to grab (a bouncing arrow points at it)
# and the tile to drop on (a pulsing ring). The overlay ignores the mouse, so
# taps still reach the board.

const _RING_TEXTURE := preload("res://assets/vfx/soft_ring.png")
const _ARROW_TEXTURE := preload("res://assets/ui/icons/arrow_right.png")
const _GOLD := Color(0.83, 0.68, 0.36)
const _DIM := Color(0.03, 0.035, 0.05, 0.72)
const _HOLE_PAD := 58.0
const _EXPLAIN_SECONDS := 3.4

var _board: Node = null
var _battle: Node = null

var _running: bool = false
var _tap_flag: bool = false
var _arrow_time: float = 0.0

# Latched true whenever the board hands a fresh turn back to the player. Reset
# at the start of each forced move so we can tell exactly when THAT move has
# fully resolved, without racing the player_turn_started signal.
var _pt_latched: bool = false

# Latched true when the player actually drops the locked hero on the required
# tile (Events.tutorial_move_accepted). A move only advances once BOTH this and
# the turn latch are set, so a stray player_turn_started (battle start, a
# timed-out turn, the frozen-enemy cycle) can never skip the lesson ahead.
var _drop_accepted: bool = false
var _move_requires_drop: bool = false

# The hero to spotlight this move, and the tile to drop on.
var _spot_unit: Node = null
var _target_coords_current: Vector2 = Vector2(-1, -1)

# Layout result for the current move.
var _drag_unit: Node = null
var _target_coords: Vector2 = Vector2(-1, -1)

var _root: Control
var _grab_arrow: TextureRect
var _target_marker: TextureRect
var _mask_top: ColorRect
var _mask_bottom: ColorRect
var _mask_left: ColorRect
var _mask_right: ColorRect
var _frame: Panel
var _panel: Button
var _text_label: Label
var _hint_label: Label


static func should_run() -> bool:
	return GameData.save_data != null and not GameData.save_data.tutorial_seen


func setup(board: Node, battle: Node) -> void:
	_board = board
	_battle = battle


func _ready() -> void:
	layer = 90

	_build_ui()

	# Latch every fresh player turn from now on. Connecting before the sequence
	# starts means a move can never resolve faster than we start listening.
	if _board != null and not _board.player_turn_started.is_connected(_on_player_turn):
		_board.player_turn_started.connect(_on_player_turn)

	# The board fires this the moment a correct forced drop commits.
	if not Events.tutorial_move_accepted.is_connected(_on_tutorial_move_accepted):
		Events.tutorial_move_accepted.connect(_on_tutorial_move_accepted)

	# Let the board finish placing every unit on its cell before rearranging.
	await get_tree().process_frame

	_running = true
	_run()


# ---- the scripted sequence --------------------------------------------------

func _run() -> void:
	# Enemies hold still for the whole tutorial so the board stays exactly as
	# each step arranges it and no hero can be lost while the player learns.
	Events.tutorial_freeze_enemies = true

	# MOVE 1: a two-hero pincer.
	if not _setup_pincer_layout():
		# Unexpected squad shape: guide loosely and bow out.
		_begin_move("TUT_PINCER_MOVE", _player(0), Vector2(-1, -1))
		await _await_move_resolved()
		_end_move()
		await _explain("TUT_FINISH")
		_finish()
		return

	_begin_move("TUT_PINCER_MOVE", _drag_unit, _target_coords)
	await _await_move_resolved()
	if not _running:
		return
	_end_move()
	await _explain("TUT_PINCER_DONE")
	if not _running:
		return

	# MOVE 2 + 3: the player BUILDS a chain, they do not just slot in the last
	# piece. First they line a hero up on the far side of the enemy (no pincer
	# yet), then they close the trap so the lined-up hero chains in.
	if _setup_chain_setup_layout():
		_begin_move("TUT_CHAIN_SETUP", _drag_unit, _target_coords)
		await _await_move_resolved()
		if not _running:
			return
		_end_move()

		if _setup_chain_trap_layout():
			_begin_move("TUT_CHAIN_MOVE", _drag_unit, _target_coords)
			await _await_move_resolved()
			if not _running:
				return
			_end_move()
			await _explain("TUT_CHAIN_DONE")
			if not _running:
				return

	# Done: hand the battle back to the player.
	_end_move()
	_text_label.text = tr("TUT_FINISH")
	_hint_label.text = ""
	await _wait(2.4)
	_finish()


# Enter a forced move: lock input to `unit`, lock the drop to `target`, and
# light up the hero + tile.
func _begin_move(text_key: String, unit, target: Vector2) -> void:
	_text_label.text = tr(text_key)
	_hint_label.text = ""

	_spot_unit = unit
	_target_coords_current = target

	Events.tutorial_locked_unit = unit
	Events.tutorial_required_coords = target

	# Arm the latches: the move advances only once the player has both dropped on
	# the required tile (_drop_accepted) AND the board has handed the turn back
	# (_pt_latched). A wrong-drop snap-back starts no turn; a stray turn start
	# carries no accepted drop. Neither alone advances the lesson.
	_pt_latched = false
	_drop_accepted = false
	_move_requires_drop = target.x >= 0.0

	_panel.modulate.a = 0.35
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.22)


func _end_move() -> void:
	_spot_unit = null
	_target_coords_current = Vector2(-1, -1)
	Events.tutorial_locked_unit = null
	Events.tutorial_required_coords = Vector2(-1, -1)


# Show an explanation; advance on a tap or after a short delay so it can never
# feel stuck.
func _explain(text_key: String) -> void:
	_text_label.text = tr(text_key)
	_hint_label.text = tr("TUT_CONTINUE")
	_spot_unit = null
	_target_coords_current = Vector2(-1, -1)

	_panel.modulate.a = 0.35
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.22)

	_tap_flag = false
	var elapsed := 0.0
	while _running and not _tap_flag and elapsed < _EXPLAIN_SECONDS:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_hint_label.text = ""


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while _running and elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


# Wait until the current forced move has fully resolved: the drop is accepted,
# the pincer (if any) plays out, and the board hands a fresh turn back. Polling
# the latch (set by player_turn_started, armed in _begin_move) avoids racing the
# signal, which can fire before or after any explanation delay. Skip-safe: a
# Skip clears _running and drops us straight out.
func _await_move_resolved() -> void:
	# A move with a required tile needs the real drop; the loose fallback move
	# (no target) only has the turn latch to go on.
	while _running and not (_pt_latched and (_drop_accepted or not _move_requires_drop)):
		await get_tree().process_frame


func _on_player_turn() -> void:
	_pt_latched = true


func _on_tutorial_move_accepted() -> void:
	_drop_accepted = true


func _on_callout_tapped() -> void:
	_tap_flag = true


func _on_skip_pressed() -> void:
	_finish()


func _finish() -> void:
	if not _running:
		return

	_running = false
	_end_move()
	Events.tutorial_freeze_enemies = false

	if GameData.save_data != null and not GameData.save_data.tutorial_seen:
		GameData.save_data.tutorial_seen = true
		GameData.save()

	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _notification(what: int) -> void:
	# Never leave the board gated or the enemies frozen if the guide is torn
	# down unexpectedly.
	if what == NOTIFICATION_PREDELETE:
		Events.tutorial_locked_unit = null
		Events.tutorial_required_coords = Vector2(-1, -1)
		Events.tutorial_freeze_enemies = false


# ---- per-frame highlight ----------------------------------------------------

func _process(delta: float) -> void:
	_arrow_time += delta

	# Spotlight the hero to drag; a gold arrow shows the gesture.
	if _spot_unit != null and is_instance_valid(_spot_unit):
		var rect := _unit_rect(_spot_unit)
		_set_spotlight_visible(true)
		_layout_spotlight(rect)

		var from: Vector2 = rect.get_center()
		var target_pos = _target_cell_screen_pos()
		_grab_arrow.visible = true

		if target_pos != null:
			# Sweep the arrow along the whole drag path, hero -> marked tile, on
			# a loop, pointing the way, so the player sees exactly where to drag.
			var to: Vector2 = target_pos
			var period := 1.5
			var t: float = fmod(_arrow_time, period) / period
			var eased: float = t * t * (3.0 - 2.0 * t)          # smoothstep
			_grab_arrow.rotation = (to - from).angle()
			_grab_arrow.position = from.lerp(to, eased) - _grab_arrow.size * 0.5
			# Fade in leaving the hero, out arriving at the tile: reads as a sweep.
			_grab_arrow.modulate = Color(_GOLD.r, _GOLD.g, _GOLD.b, clampf(sin(t * PI) * 1.6, 0.12, 1.0))
		else:
			# No destination (loose fallback move): bob above the hero.
			var bob: float = sin(_arrow_time * 6.0) * 6.0
			_grab_arrow.rotation = PI / 2.0
			_grab_arrow.modulate = _GOLD
			_grab_arrow.position = Vector2(
					from.x - _grab_arrow.size.x * 0.5,
					rect.position.y - _grab_arrow.size.y - 8.0 + bob)
	else:
		_set_spotlight_visible(false)
		_grab_arrow.visible = false

	# Pulsing ring on the tile to drop on.
	var marker_pos = _target_cell_screen_pos()
	if marker_pos == null:
		_target_marker.visible = false
	else:
		_target_marker.visible = true
		_target_marker.position = (marker_pos as Vector2) - _target_marker.size * 0.5


# ---- scripted layouts -------------------------------------------------------

# Two heroes flank an enemy: drag the lone hero up to complete the pincer.
func _setup_pincer_layout() -> bool:
	var grid = _board.get_node_or_null("Grid")
	if grid == null:
		return false

	var players := _alive(_board._player_units_node)
	var enemies := _alive(_board._enemy_units_node)

	if players.size() < 2 or enemies.is_empty():
		return false

	_vacate(grid, players + enemies)

	_place(grid, players[1], Vector2(2, 3))   # partner holds one side
	_place(grid, enemies[0], Vector2(3, 3))   # enemy to trap
	_place(grid, players[0], Vector2(4, 5))   # the hero the player drags
	_drag_unit = players[0]
	_target_coords = Vector2(4, 3)

	var spare := [Vector2(0, 7), Vector2(1, 7), Vector2(0, 6), Vector2(1, 6)]
	for i in range(2, players.size()):
		if i - 2 < spare.size():
			_place(grid, players[i], spare[i - 2])

	var espare := [Vector2(5, 0), Vector2(4, 0), Vector2(5, 1)]
	for i in range(1, enemies.size()):
		if i - 1 < espare.size():
			_place(grid, enemies[i], espare[i - 1])

	return true


# CHAIN, part 1 (line up): the enemy and one partner are set. The player drags
# a hero to the FAR side of the enemy so it sits in line with it. No pincer
# forms yet, so nothing fires: this move just gets the hero into position.
#   row 3:   partner(2) . enemy(3) . [gap](4) . DROP HERE(5)
func _setup_chain_setup_layout() -> bool:
	var grid = _board.get_node_or_null("Grid")
	if grid == null:
		return false

	var players := _alive(_board._player_units_node)
	var enemies := _alive(_board._enemy_units_node)

	if players.size() < 3 or enemies.is_empty():
		return false

	_vacate(grid, players + enemies)

	_place(grid, players[1], Vector2(2, 3))   # partner holds the near side
	_place(grid, enemies[0], Vector2(3, 3))   # enemy to trap
	_place(grid, players[0], Vector2(4, 5))   # the trap hero waits below col 4
	_place(grid, players[2], Vector2(5, 5))   # the hero to line up waits below col 5
	_drag_unit = players[2]
	_target_coords = Vector2(5, 3)

	_park_extras(grid, players, enemies, 3)
	return true


# CHAIN, part 2 (close the trap): partner, enemy and the just-lined-up hero are
# all in place. The player drags the last hero between the partner and the enemy
# so the pincer forms AND the hero already in line beyond it chains in.
#   row 3:   partner(2) . enemy(3) . DROP HERE(4) . chains in(5)
func _setup_chain_trap_layout() -> bool:
	var grid = _board.get_node_or_null("Grid")
	if grid == null:
		return false

	var players := _alive(_board._player_units_node)
	var enemies := _alive(_board._enemy_units_node)

	if players.size() < 3 or enemies.is_empty():
		return false

	_vacate(grid, players + enemies)

	_place(grid, players[1], Vector2(2, 3))   # partner (far pincer side)
	_place(grid, enemies[0], Vector2(3, 3))   # enemy to trap
	_place(grid, players[2], Vector2(5, 3))   # the hero the player just lined up
	_place(grid, players[0], Vector2(4, 5))   # the trap hero waits below col 4
	_drag_unit = players[0]
	_target_coords = Vector2(4, 3)

	_park_extras(grid, players, enemies, 3)
	return true


# Tuck any heroes past the first `used` and any spare enemies into the corners
# so they take no part in the scripted move.
func _park_extras(grid, players: Array, enemies: Array, used: int) -> void:
	var spare := [Vector2(0, 7), Vector2(1, 7), Vector2(0, 6)]
	for i in range(used, players.size()):
		if i - used < spare.size():
			_place(grid, players[i], spare[i - used])

	var espare := [Vector2(5, 0), Vector2(4, 0), Vector2(5, 1)]
	for i in range(1, enemies.size()):
		if i - 1 < espare.size():
			_place(grid, enemies[i], espare[i - 1])


func _vacate(grid, units: Array) -> void:
	for u in units:
		var c = grid.get_cell_from_position(u.position)
		if c != null and c.unit == u:
			c.unit = null


func _place(grid, unit, coords: Vector2) -> void:
	var cell = grid.get_cell_from_coordinates(coords)
	if cell == null:
		return
	cell.unit = unit
	unit.position = cell.position


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


func _player(index: int):
	var alive := _alive(_board._player_units_node)
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


# ---- spotlight layout -------------------------------------------------------

func _set_spotlight_visible(v: bool) -> void:
	_mask_top.visible = v
	_mask_bottom.visible = v
	_mask_left.visible = v
	_mask_right.visible = v
	_frame.visible = v


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


# ---- construction -----------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Four dark quads dim everything outside the spotlight hole. They ignore
	# the mouse, so clicks still reach the hero underneath.
	_mask_top = _make_dim()
	_mask_bottom = _make_dim()
	_mask_left = _make_dim()
	_mask_right = _make_dim()

	# A clean thin frame around the hero (no filled glow "sitting on the tile").
	_frame = Panel.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color(0, 0, 0, 0)
	fstyle.border_color = _GOLD
	fstyle.set_border_width_all(2)
	fstyle.set_corner_radius_all(10)
	_frame.add_theme_stylebox_override("panel", fstyle)
	_root.add_child(_frame)

	# A gold arrow that bounces above the hero, pointing down at it.
	_grab_arrow = TextureRect.new()
	_grab_arrow.texture = _ARROW_TEXTURE
	_grab_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_grab_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_grab_arrow.size = Vector2(38, 38)
	_grab_arrow.pivot_offset = _grab_arrow.size * 0.5
	_grab_arrow.rotation = PI / 2.0   # arrow_right -> points down
	_grab_arrow.modulate = _GOLD
	_grab_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grab_arrow.visible = false
	_root.add_child(_grab_arrow)

	# The pulsing "drop here" ring on the target tile.
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
	# The callout: an ink plate near the bottom, sized/placed explicitly (a
	# Button does not grow to fit Control children) so it always fits on-screen.
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

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 18)
	_text_label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.position = Vector2(16, 14)
	_text_label.size = Vector2(_panel.size.x - 32, panel_h - 50)
	_panel.add_child(_text_label)

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
	skip.pressed.connect(_on_skip_pressed)
	bottom_row.add_child(skip)
