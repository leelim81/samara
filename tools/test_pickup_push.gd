extends SceneTree
# Verifies battle drop-ins (Powered Points and capsules) are SHOVED ASIDE when
# a unit is dragged onto their tile (Terra Battle behavior), instead of being
# covered. Uses the validated real-drag primitive from test_drag_move.gd:
# drag A onto a powered cell -> the point slides to the next free tile in the
# drag direction (not consumed); then drag A onto a capsule cell -> the
# capsule slides aside with its coin amount intact.
#   godot --headless --script res://tools/test_pickup_push.gd

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

	var players: Array = board._player_units_node.get_children()
	if players.is_empty():
		printerr("FAIL: no players")
		quit(1)
		return
	var a = players[0]

	# Keep everyone away from the drag lane so no pincer fires on release.
	_park_units(grid, board, a)
	_teleport(grid, a, grid.get_cell_from_coordinates(Vector2(3, 6)))

	# --- Drag UP onto a Powered Point ---
	var powered_cell = grid.get_cell_from_coordinates(Vector2(3, 5))
	var ahead_cell = grid.get_cell_from_coordinates(Vector2(3, 4))
	_plant_powered(board, powered_cell)

	await _drag_move(board, grid, a, powered_cell)

	_check("unit landed on the powered tile", _cell_of(grid, a) == powered_cell)
	_check("powered point was pushed off the tile", not powered_cell.is_powered)
	_check("powered point slid ahead in the drag direction", ahead_cell.is_powered)
	_check("board bookkeeping follows the point", board._powered_cells.has(ahead_cell) and not board._powered_cells.has(powered_cell))
	_check("point was moved, not consumed (disc alive)", is_instance_valid(board._powered_discs.get(ahead_cell)))

	# --- Wait for the next player turn, then drag LEFT onto a capsule ---
	var back := false
	for i in 2400:
		await process_frame
		if board._current_turn == board.Turn.PLAYER:
			back = true
			break
	if not back:
		printerr("FAIL: player turn never came back")
		quit(1)
		return
	_park_units(grid, board, a)

	var capsule_cell = grid.get_cell_from_coordinates(Vector2(2, 5))
	var left_cell = grid.get_cell_from_coordinates(Vector2(1, 5))
	_plant_capsule(board, capsule_cell, 2) # CapsuleType.COIN
	board._capsule_coin_amounts[capsule_cell] = 55

	await _drag_move(board, grid, a, capsule_cell)

	_check("unit landed on the capsule tile", _cell_of(grid, a) == capsule_cell)
	_check("capsule was pushed off the tile", capsule_cell.capsule_type == 0)
	_check("capsule slid ahead in the drag direction", left_cell.capsule_type == 2)
	_check("coin amount travels with the capsule", board._capsule_coin_amounts.get(left_cell, -1) == 55)
	_check("capsule disc alive at the new tile", is_instance_valid(board._capsule_discs.get(left_cell)))

	print("test_pickup_push: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


# Enemies to row 0, other players to row 7 — far from the (1..3, 4..6) lane.
func _park_units(grid, board, dragged) -> void:
	var x := 0
	for e in board._enemy_units_node.get_children():
		if e.is_alive() and not e.is2x2():
			_teleport(grid, e, grid.get_cell_from_coordinates(Vector2(x, 0)))
			x += 1
	var px := 5
	for p in board._player_units_node.get_children():
		if p != dragged:
			_teleport(grid, p, grid.get_cell_from_coordinates(Vector2(px, 7)))
			px -= 1


func _plant_powered(board, cell) -> void:
	cell.is_powered = true
	board._powered_cells.push_back(cell)
	var disc = board.POWERED_POINT_SCENE.instantiate()
	board._powered_points.add_child(disc)
	disc.position = cell.position
	board._powered_discs[cell] = disc


func _plant_capsule(board, cell, capsule_type: int) -> void:
	cell.capsule_type = capsule_type
	var disc = board.CAPSULE_SCENE.instantiate()
	board._capsules_node.add_child(disc)
	disc.position = cell.position
	disc.initialize(capsule_type)
	board._capsule_discs[cell] = disc


# --- real drag-move primitive (same as test_drag_move.gd) ---
func _drag_move(board, grid, unit, target_cell) -> bool:
	if target_cell == null:
		return false
	await _wait_idle(unit)
	var start_cell = _snap_pos_to_cell(grid, unit)
	if start_cell == null or start_cell == target_cell:
		return false
	if unit.current_state != unit.STATE.IDLE:
		return false

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


func _teleport(grid, unit, target_cell) -> void:
	var current_cell = _cell_of(grid, unit)
	if current_cell != null and current_cell.unit == unit:
		current_cell.unit = null
	if target_cell.unit != null and target_cell.unit != unit and current_cell != null:
		var displaced = target_cell.unit
		displaced.position = current_cell.position
		current_cell.unit = displaced
	target_cell.unit = unit
	unit.position = target_cell.position


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1
	print(("  PASS " if cond else "  FAIL ") + label)
