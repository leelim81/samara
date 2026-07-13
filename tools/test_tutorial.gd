extends SceneTree
# Tests the scripted on-rails first-battle tutorial:
#   - it rearranges the board into a fixed layout (partner, enemy, draggable),
#   - locks input to one hero AND the drop to one tile,
#   - advances only on the taught action,
#   - and the board snaps a wrong drop back to origin without resolving the turn.
# Never completes the final step, so the guide never writes the save file.
#   godot --headless --script res://tools/test_tutorial.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	var board = battle.get_node("Board")
	var grid = board.get_node("Grid")
	var events = root.get_node("/root/Events")

	var reached := false
	for i in 1200:
		await process_frame
		if board._current_turn == board.Turn.PLAYER:
			reached = true
			break
	if not reached:
		printerr("FAIL: player turn never started")
		quit(1)
		return

	# Runtime-load the guide (avoids the --script class_name compile-order trap).
	var guide = load("res://ui/tutorial_guide.gd").new()
	guide.setup(board, battle)
	battle.add_child(guide)

	# _ready awaits a frame then rearranges the board and enters step 0.
	for i in 6:
		await process_frame

	# ---- scripted layout --------------------------------------------------
	_check("partner hero placed at (2,3)", _is_player(grid, board, Vector2(2, 3)))
	_check("enemy placed at (3,3)", _is_enemy(grid, board, Vector2(3, 3)))
	_check("draggable hero placed at (4,5)", _cell_unit(grid, Vector2(4, 5)) == guide._drag_unit)
	_check("target tile is (4,3)", guide._target_coords == Vector2(4, 3))

	# ---- step 0: forced drag ----------------------------------------------
	_check("step 0 shows the drag callout", guide._text_label.text == tr("TUT_DRAG_HERE"))
	_check("input is locked to the draggable hero", events.tutorial_locked_unit == guide._drag_unit)
	_check("drop is locked to the target tile", events.tutorial_required_coords == Vector2(4, 3))
	_check("board reports a required cell", events.tutorial_requires_cell())
	_check("tapping does NOT advance a forced step", not guide._tap_advances)

	# ---- board drop-lock: a wrong drop snaps back, does not resolve --------
	var u = guide._drag_unit
	var origin = grid.get_cell_from_position(u.position)
	board._tutorial_origin_cell = origin
	board._has_active_unit_exited_cell = true
	# Simulate the unit having been dropped on the WRONG cell (0,0).
	var wrong = grid.get_cell_from_coordinates(Vector2(0, 0))
	if wrong.unit != null and wrong.unit != u:
		wrong.unit = null
	origin.unit = null
	wrong.unit = u
	u.position = wrong.position
	board._current_turn = board.Turn.PLAYER

	await board._on_Unit_snapped_to_grid(u)

	_check("wrong drop snaps the hero back to origin", grid.get_cell_from_position(u.position) == origin and origin.unit == u)
	_check("wrong drop leaves the wrong cell empty", wrong.unit == null)
	_check("wrong drop keeps it the player's turn", board._current_turn == board.Turn.PLAYER)

	# ---- step advancement --------------------------------------------------
	events.emit_signal("cutin_requested", [], "", true, Color.WHITE, false)
	await process_frame
	_check("a pincer advances to the explanation step", guide._text_label.text == tr("TUT_PINCER_DONE"))
	_check("explanation step clears the drop lock", not events.tutorial_requires_cell())
	_check("explanation step advances on tap", guide._tap_advances)

	guide._on_callout_tapped()
	await process_frame
	_check("tap advances to the finish step", guide._text_label.text == tr("TUT_FINISH"))
	_check("finish step releases the input lock", events.tutorial_locked_unit == null)
	_check("finish step releases the drop lock", not events.tutorial_requires_cell())

	# Quit before the finish timer fires so the guide never saves.
	print("test_tutorial: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _cell_unit(grid, coords: Vector2):
	var cell = grid.get_cell_from_coordinates(coords)
	return cell.unit if cell != null else null


func _is_player(grid, board, coords: Vector2) -> bool:
	var unit = _cell_unit(grid, coords)
	return unit != null and unit in board._player_units_node.get_children()


func _is_enemy(grid, board, coords: Vector2) -> bool:
	var unit = _cell_unit(grid, coords)
	return unit != null and unit in board._enemy_units_node.get_children()


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1
	print(("  PASS " if cond else "  FAIL ") + label)
