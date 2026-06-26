extends SceneTree
# End-to-end Powered Point test through the real combat pipeline: spawn a Powered
# Point on one flank cell, teleport a striker onto it, run a real pincer, and
# assert the point is CONSUMED. The consume firing proves the whole chain:
# pincer_executor detected the unit on the powered cell, set is_on_powered_point
# (forcing 100% activation), emitted powered_point_consumed, and board cleared it.
#   godot --headless --script res://tools/test_powered_point_integration.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	var board = battle.get_node("Board")

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

	var grid = board.get_node("Grid")
	var players: Array = board._player_units_node.get_children()
	var enemies: Array = board._enemy_units_node.get_children()

	var enemy = null
	for c in enemies:
		if c.is_alive() and not c.is2x2():
			enemy = c
			break
	if enemy == null or players.size() < 2:
		printerr("FAIL: not enough units")
		quit(1)
		return

	# Park the enemy in the middle so both flank cells exist.
	var enemy_cell = grid.get_cell_from_position(enemy.position)
	var mid = grid.get_cell_from_coordinates(Vector2(2, 4))
	if mid.unit == null:
		enemy_cell.unit = null
		mid.unit = enemy
		enemy.position = mid.position
		enemy_cell = mid
	var coords: Vector2 = enemy_cell.coordinates
	var left = grid.get_cell_from_coordinates(coords + Vector2.LEFT)
	var right = grid.get_cell_from_coordinates(coords + Vector2.RIGHT)

	# Plant a Powered Point on the LEFT flank cell (where the lead striker lands).
	left.is_powered = true
	board._powered_cells.push_back(left)
	var disc = board.POWERED_POINT_SCENE.instantiate()
	board._powered_points.add_child(disc)
	disc.position = left.position
	board._powered_discs[left] = disc

	var a = players[0]
	var b = players[1]
	_teleport(grid, a, left)
	_teleport(grid, b, right)

	_check("precondition: cell is powered before pincer", left.is_powered)

	await board._execute_pincers(a)
	for i in 30:
		await process_frame

	_check("powered cell consumed (is_powered=false)", not left.is_powered)
	_check("powered cell removed from active list", not board._powered_cells.has(left))
	_check("disc freed", not is_instance_valid(disc))

	print("test_powered_point_integration: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _teleport(grid, unit, target_cell) -> void:
	var current_cell = grid.get_cell_from_position(unit.position)
	if current_cell != null and current_cell.unit == unit:
		current_cell.unit = null
	if target_cell.unit != null and target_cell.unit != unit:
		var displaced = target_cell.unit
		displaced.position = current_cell.position
		current_cell.unit = displaced
	target_cell.unit = unit
	unit.position = target_cell.position


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1
	print(("  PASS " if cond else "  FAIL ") + label)
