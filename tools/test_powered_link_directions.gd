extends SceneTree
# Verifies a Powered Point links (chains) to the attacking units in BOTH axes:
#  - horizontal pincer: point above a pincering unit (vertical link) and point
#    beside one on the pincer row (horizontal link)
#  - vertical pincer: point beside a pincering unit (horizontal link) and
#    point below one on the pincer column (vertical link)
# Then runs a real pincer end-to-end and asserts both linked points are
# consumed and the turn-wide power boost fired.
#   godot --headless --script res://tools/test_powered_link_directions.gd

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
	var pincerer = board.get_node("Pincerer")
	var players: Array = board._player_units_node.get_children()
	var enemies: Array = []
	for e in board._enemy_units_node.get_children():
		if e.is_alive() and not e.is2x2():
			enemies.push_back(e)

	if players.size() < 2 or enemies.is_empty():
		printerr("FAIL: not enough units")
		quit(1)
		return

	# Park spare enemies away from every line used below (avoid row 4, row 3,
	# col 2, col 3, col 0 above row 4).
	var parking := [Vector2(0, 6), Vector2(5, 6), Vector2(1, 6), Vector2(4, 6), Vector2(0, 5), Vector2(5, 5)]
	for i in range(1, enemies.size()):
		if i - 1 < parking.size():
			_teleport(grid, enemies[i], grid.get_cell_from_coordinates(parking[i - 1]))
	for i in range(2, players.size()):
		_teleport(grid, players[i], grid.get_cell_from_coordinates(Vector2(i - 2, 7)))

	var enemy = enemies[0]
	var a = players[0]
	var b = players[1]

	# ---- Case A: HORIZONTAL pincer A(1,4) E(2,4) B(3,4) ----
	_teleport(grid, enemy, grid.get_cell_from_coordinates(Vector2(2, 4)))
	_teleport(grid, a, grid.get_cell_from_coordinates(Vector2(1, 4)))
	_teleport(grid, b, grid.get_cell_from_coordinates(Vector2(3, 4)))

	var pp_vertical = grid.get_cell_from_coordinates(Vector2(3, 1))  # above B, gaps between
	var pp_horizontal = grid.get_cell_from_coordinates(Vector2(0, 4))  # left of A, same row
	pp_vertical.is_powered = true
	pp_horizontal.is_powered = true

	var pincer = _leading_pincer(pincerer, grid, a)
	if pincer == null:
		printerr("FAIL: no horizontal leading pincer")
		quit(1)
		return
	pincerer.find_chains(grid, pincer)

	_check("horizontal pincer links a point VERTICALLY (above B)",
			pincer.chained_powered_cells.has(pp_vertical))
	_check("horizontal pincer links a point HORIZONTALLY (left of A)",
			pincer.chained_powered_cells.has(pp_horizontal))

	pp_vertical.is_powered = false
	pp_horizontal.is_powered = false

	# ---- Case B: VERTICAL pincer A(2,3) E(2,4) B(2,5) ----
	_teleport(grid, a, grid.get_cell_from_coordinates(Vector2(2, 3)))
	_teleport(grid, b, grid.get_cell_from_coordinates(Vector2(2, 5)))

	var pp_beside = grid.get_cell_from_coordinates(Vector2(5, 3))  # right of A, same row
	var pp_below = grid.get_cell_from_coordinates(Vector2(2, 7))  # below B, same column
	pp_beside.is_powered = true
	pp_below.is_powered = true

	pincer = _leading_pincer(pincerer, grid, a)
	if pincer == null:
		printerr("FAIL: no vertical leading pincer")
		quit(1)
		return
	pincerer.find_chains(grid, pincer)

	_check("vertical pincer links a point HORIZONTALLY (beside A)",
			pincer.chained_powered_cells.has(pp_beside))
	_check("vertical pincer links a point VERTICALLY (below B)",
			pincer.chained_powered_cells.has(pp_below))

	pp_beside.is_powered = false
	pp_below.is_powered = false

	# ---- End-to-end: re-plant the case-A points with real discs, run the
	# pincer for real, and assert both are consumed and the boost fired ----
	_teleport(grid, a, grid.get_cell_from_coordinates(Vector2(1, 4)))
	_teleport(grid, b, grid.get_cell_from_coordinates(Vector2(3, 4)))
	_plant_real(board, pp_vertical)
	_plant_real(board, pp_horizontal)

	var events = root.get_node("/root/Events")
	var boost_seen := [false]
	events.power_boost_changed.connect(func(active): if active: boost_seen[0] = true)

	await board._execute_pincers(a)

	_check("vertically linked point consumed by the real pincer", not pp_vertical.is_powered)
	_check("horizontally linked point consumed by the real pincer", not pp_horizontal.is_powered)
	_check("power boost activated during the pincer", boost_seen[0])

	print("test_powered_link_directions: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


# Registers the point with the board like a real spawn, so consumption
# (board._clear_powered_point) accepts and clears it.
func _plant_real(board, cell) -> void:
	cell.is_powered = true
	board._powered_cells.push_back(cell)
	var disc = board.POWERED_POINT_SCENE.instantiate()
	board._powered_points.add_child(disc)
	disc.position = cell.position
	board._powered_discs[cell] = disc


func _leading_pincer(pincerer, grid, active_unit):
	var pincers: Array = pincerer.find_pincers(grid, active_unit)
	for pincer in pincers:
		if pincer.pincering_units.has(active_unit):
			return pincer
	return null


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
