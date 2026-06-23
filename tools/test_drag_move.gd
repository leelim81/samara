extends SceneTree
# Stage-0 validation of the real drag-move primitive (the basis of the bot
# rewrite): pick up a player unit, step its position cell-by-cell awaiting
# PHYSICS frames so the SwapArea2D overlaps Cells, release -> snap. Asserts the
# unit actually committed to the target cell via the engine's real move path
# (not a teleport), and ended IDLE. Run:
#   godot --headless --script res://tools/test_drag_move.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	var board = battle.get_node("Board")
	var grid = board.get_node("Grid")

	var reached := false
	for i in 1200:
		await process_frame
		if board._current_turn == board.Turn.PLAYER:
			reached = true
			break
	if not reached:
		printerr("FAIL: no player turn")
		quit(1)
		return
	for j in 25:
		await process_frame

	var player = null
	for u in board._player_units_node.get_children():
		if u.is_alive():
			player = u
			break
	if player == null:
		printerr("FAIL: no player")
		quit(1)
		return

	var start_cell = _cell_of(grid, player)
	# find an adjacent EMPTY in-range cell (a clean 1-tile drag, no bump/pincer)
	var target = null
	for dir in [Enums.DIRECTION.RIGHT, Enums.DIRECTION.LEFT, Enums.DIRECTION.UP, Enums.DIRECTION.DOWN]:
		var n = start_cell.get_neighbor(dir)
		if n != null and n.unit == null:
			target = n
			break
	if target == null:
		printerr("FAIL: no adjacent empty cell")
		quit(1)
		return

	print("dragging %s from %s to %s" % [player.name, start_cell.coordinates, target.coordinates])
	await _drag_move(board, grid, player, target)
	for k in 40:
		await process_frame

	var landed = _cell_of(grid, player)
	_check("player committed to target cell via real drag", landed == target)
	_check("player ended IDLE", player.current_state == player.STATE.IDLE)

	print("test_drag_move: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


# --- real drag-move primitive (per design spec) ---
func _drag_move(board, grid, unit, target_cell) -> bool:
	if target_cell == null:
		return false
	await _wait_idle(unit)
	var start_cell = _snap_pos_to_cell(grid, unit)
	if start_cell == null or start_cell == target_cell:
		return false
	if unit.current_state != unit.STATE.IDLE:
		return false

	# Headless: a PICKED_UP player unit chases get_global_mouse_position() (=> 0,0)
	# in _physics_process. Disable input control so we drive its position directly.
	var was_controlled = unit.is_controlled_by_player
	unit.is_controlled_by_player = false

	unit._pick_up()
	await physics_frame
	await process_frame
	if board._active_unit != unit:
		if unit.is_picked_up():
			unit.release()
		unit.is_controlled_by_player = was_controlled
		return false

	for step_coord in _cell_path(start_cell.coordinates, target_cell.coordinates):
		var step_cell = grid.get_cell_from_coordinates(step_coord)
		# Glide across the tile over a few physics frames so the SwapArea2D
		# sweeps the cell boundary and fires enter/exit cleanly.
		var from_pos = unit.position
		for s in range(1, 6):
			unit.position = from_pos.lerp(step_cell.position, float(s) / 5.0)
			await physics_frame
		if board._active_unit != unit or not unit.is_picked_up():
			break

	if unit.is_picked_up():
		unit.release()

	unit.is_controlled_by_player = was_controlled

	for _k in 30:
		await process_frame
		if board._current_turn != board.Turn.PLAYER:
			break
	return true


func _phys() -> void:
	await physics_frame


func _wait_idle(unit) -> void:
	for _i in 240:
		if unit.current_state == unit.STATE.IDLE:
			return
		await process_frame


func _snap_pos_to_cell(grid, unit):
	var cell = _cell_of(grid, unit)
	if cell != null:
		unit.position = cell.position
	return cell


func _cell_path(a: Vector2, b: Vector2) -> Array:
	var path := []
	var cur := a
	while int(cur.x) != int(b.x):
		cur = cur + Vector2(sign(b.x - cur.x), 0)
		path.push_back(cur)
	while int(cur.y) != int(b.y):
		cur = cur + Vector2(0, sign(b.y - cur.y))
		path.push_back(cur)
	return path


func _cell_of(grid, unit):
	for x in grid.width:
		for y in grid.height:
			var cell = grid.get_cell_from_coordinates(Vector2(x, y))
			if cell != null and cell.unit == unit:
				return cell
	return null


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1
	print(("  PASS " if cond else "  FAIL ") + label)
