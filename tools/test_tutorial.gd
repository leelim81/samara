extends SceneTree
# Tests the scripted on-rails first-battle tutorial:
#   - it rearranges the board into a fixed pincer layout,
#   - locks input to one hero AND the drop to one tile,
#   - the board snaps a wrong drop back to origin without resolving the turn,
#   - the pincer advances it to the explanation and clears the locks,
#   - and the chain layout lines up a third hero.
# Quits before completion so the guide never writes the save file.
#   godot --headless --script res://tools/test_tutorial.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Force a fresh 3-hero squad so the chain move (needs 3) is exercised.
	var default_save = load("res://save_data/default_save_data.tres")
	var sd = default_save.duplicate()
	sd.jobs = []
	for job in default_save.jobs:
		var j = job.duplicate()
		j.stats = j.stats.duplicate()
		j.source_path = job.source_path if job.source_path != "" else job.resource_path
		sd.jobs.push_back(j)
	sd.active_units = [0, 1, 2]
	root.get_node("/root/GameData").save_data = sd

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

	# _ready awaits a frame, then _run sets up the pincer move.
	for i in 8:
		await process_frame

	# ---- scripted pincer layout -------------------------------------------
	_check("partner hero placed at (2,3)", _is_player(grid, board, Vector2(2, 3)))
	_check("enemy placed at (3,3)", _is_enemy(grid, board, Vector2(3, 3)))
	_check("draggable hero placed at (4,5)", _cell_unit(grid, Vector2(4, 5)) == guide._drag_unit)
	_check("target tile is (4,3)", guide._target_coords == Vector2(4, 3))

	# ---- move 1 gates ------------------------------------------------------
	_check("move shows the pincer callout", guide._text_label.text == tr("TUT_PINCER_MOVE"))
	_check("input is locked to the draggable hero", events.tutorial_locked_unit == guide._drag_unit)
	_check("drop is locked to the target tile", events.tutorial_required_coords == Vector2(4, 3))

	# ---- board drop-lock: a wrong drop snaps back, does not resolve --------
	var u = guide._drag_unit
	var origin = grid.get_cell_from_position(u.position)
	board._tutorial_origin_cell = origin
	board._has_active_unit_exited_cell = true
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

	# ---- the pincer resolves -> explanation, locks released ---------------
	events.emit_signal("cutin_requested", [null], "", true, Color.WHITE, false)
	for i in 4:
		await process_frame
	_check("pincer advances to the explanation", guide._text_label.text == tr("TUT_PINCER_DONE"))
	_check("explanation releases the input lock", events.tutorial_locked_unit == null)
	_check("explanation releases the drop lock", not events.tutorial_requires_cell())

	# ---- chain layout lines up a third hero -------------------------------
	if _alive_players(board) >= 3:
		_check("chain layout returns true with 3 heroes", guide._setup_chain_layout())
		_check("chain hero lined up at (5,3)", _is_player(grid, board, Vector2(5, 3)))

	print("test_tutorial: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _alive_players(board) -> int:
	var n := 0
	for u in board._player_units_node.get_children():
		if u.is_alive():
			n += 1
	return n


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
