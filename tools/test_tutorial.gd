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

	# ---- the board is frozen and a wrong drop did NOT advance -------------
	_check("tutorial freezes enemy turns", events.tutorial_freeze_enemies)
	_check("wrong drop keeps the pincer move on screen", guide._text_label.text == tr("TUT_PINCER_MOVE"))
	_check("wrong drop never accepts the move", not guide._drop_accepted)

	# ---- the pincer resolves -> explanation -------------------------------
	# A move advances only on BOTH the accepted-drop signal (the board fires it
	# on a correct drop) AND a fresh player turn, so neither a stray turn start
	# nor a rejected drop can skip the lesson ahead.
	events.emit_signal("tutorial_move_accepted")
	board.emit_signal("player_turn_started")
	await _await_text(guide, "TUT_PINCER_DONE")
	_check("pincer advances to the explanation", guide._text_label.text == tr("TUT_PINCER_DONE"))
	_check("explanation releases the input lock", events.tutorial_locked_unit == null)
	_check("explanation releases the drop lock", not events.tutorial_requires_cell())
	guide._tap_flag = true   # skip the explanation dwell

	if _alive_players(board) >= 3:
		# ---- CHAIN part 1: the player lines a hero up far down the row -----
		await _await_text(guide, "TUT_CHAIN_SETUP")
		_check("chain setup places partner at (0,3)", _is_player(grid, board, Vector2(0, 3)))
		_check("chain setup places enemy at (1,3)", _is_enemy(grid, board, Vector2(1, 3)))
		_check("chain setup drags the third hero", guide._drag_unit == guide._player(2))
		_check("chain setup target is the far tile (5,3)", guide._target_coords == Vector2(5, 3))
		_check("chain setup locks input to the third hero", events.tutorial_locked_unit == guide._drag_unit)
		_check("chain setup locks the drop to (5,3)", events.tutorial_required_coords == Vector2(5, 3))

		# resolve the line-up move (no pincer): accepted drop + fresh player turn
		events.emit_signal("tutorial_move_accepted")
		board.emit_signal("player_turn_started")

		# ---- CHAIN part 2: the player closes the trap; the far hero chains -
		await _await_text(guide, "TUT_CHAIN_MOVE")
		_check("chain trap keeps the support hero out at (5,3)", _is_player(grid, board, Vector2(5, 3)))
		_check("chain trap places enemy at (1,3)", _is_enemy(grid, board, Vector2(1, 3)))
		_check("chain trap leaves a gap between trap and support", _cell_unit(grid, Vector2(3, 3)) == null and _cell_unit(grid, Vector2(4, 3)) == null)
		_check("chain trap drags the first hero", guide._drag_unit == guide._player(0))
		_check("chain trap target is the pincer tile (2,3)", guide._target_coords == Vector2(2, 3))
		_check("chain trap locks the drop to (2,3)", events.tutorial_required_coords == Vector2(2, 3))

		# ---- the CHAIN actually reaches across the gap (the whole point) ----
		# Drop the trap hero on (2,3) for real and run the pincerer: the support
		# hero at (5,3) must chain in despite the two empty cells between them.
		var trap_hero = guide._player(0)
		var support_hero = guide._player(2)
		var park = grid.get_cell_from_position(trap_hero.position)
		if park != null and park.unit == trap_hero:
			park.unit = null
		var trap_cell = grid.get_cell_from_coordinates(Vector2(2, 3))
		trap_cell.unit = trap_hero
		trap_hero.position = trap_cell.position

		var pincers: Array = board.get_node("Pincerer").find_pincers(grid, trap_hero)
		_check("dropping the trap hero forms a pincer", not pincers.is_empty())
		if not pincers.is_empty():
			var pincer = pincers[0]
			board.get_node("Pincerer").find_chains(grid, pincer)
			_check("the far support hero chains across the two-tile gap", _unit_in_chains(support_hero, pincer.chain_families))

	print("test_tutorial: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


# True if `unit` appears in any chain family of a resolved pincer.
func _unit_in_chains(unit, chain_families: Dictionary) -> bool:
	for chains in chain_families.values():
		for chain in chains:
			if chain.find(unit) != -1:
				return true
	return false


# Poll until the callout shows `key`'s text, or fail after a generous timeout.
func _await_text(guide, key: String, max_frames: int = 600) -> void:
	var f := 0
	while guide._text_label.text != tr(key) and f < max_frames:
		await process_frame
		f += 1
	if guide._text_label.text != tr(key):
		_f += 1
		print("  FAIL timed out waiting for %s (saw '%s')" % [key, guide._text_label.text])


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
