extends SceneTree
# Dev-only integration test: loads the tutorial battle, teleports two player
# units so they flank the first enemy horizontally, then runs the board's
# real pincer pipeline and asserts the enemy took damage. Run with:
# godot --headless --script res://test_pincer.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/tutorial/tutorial.tscn") as PackedScene).instantiate()

	root.add_child(battle)

	var board = battle.get_node("Board")

	# Wait for the board to reach the player's turn (turn zero enemy phase
	# plays first).
	var reached_player_turn := false

	for i in 1200:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			reached_player_turn = true

			break

	if not reached_player_turn:
		printerr("TEST FAIL: player turn never started")

		quit(1)

		return

	print("TEST: player turn reached")

	var grid = board.get_node("Grid")
	var players: Array = board._player_units_node.get_children()
	var enemies: Array = board._enemy_units_node.get_children()

	var enemy = null

	for candidate in enemies:
		if candidate.is_alive() and not candidate.is2x2():
			enemy = candidate

			break

	if enemy == null or players.size() < 2:
		printerr("TEST FAIL: not enough units on board (players: %d)" % players.size())

		quit(1)

		return

	var enemy_cell = grid.get_cell_from_position(enemy.position)
	var coordinates: Vector2 = enemy_cell.coordinates

	# Find a horizontal flanking pair inside the grid. The grid is 6 wide, so
	# x-1 and x+1 exist unless the enemy hugs a border; move the enemy to the
	# middle first to keep it simple.
	var middle_cell = grid.get_cell_from_coordinates(Vector2(2, 4))

	if middle_cell.unit == null:
		enemy_cell.unit = null
		middle_cell.unit = enemy
		enemy.position = middle_cell.position
		enemy_cell = middle_cell
		coordinates = enemy_cell.coordinates

	var left_cell = grid.get_cell_from_coordinates(coordinates + Vector2.LEFT)
	var right_cell = grid.get_cell_from_coordinates(coordinates + Vector2.RIGHT)

	var ally_a = players[0]
	var ally_b = players[1]

	_teleport(grid, ally_a, left_cell)
	_teleport(grid, ally_b, right_cell)

	var health_before: int = enemy.get_stats().health

	print("TEST: enemy health before pincer: %d" % health_before)

	await board._execute_pincers(ally_a)

	# Give death animations a moment in case the pincer was lethal.
	for i in 30:
		await process_frame

	var health_after: int = enemy.get_stats().health

	print("TEST: enemy health after pincer: %d" % health_after)

	if health_after < health_before:
		print("TEST PASS: pincer dealt %d damage" % (health_before - health_after))

		quit(0)
	else:
		printerr("TEST FAIL: pincer dealt no damage")

		quit(1)


func _teleport(grid, unit, target_cell) -> void:
	var current_cell = grid.get_cell_from_position(unit.position)

	if current_cell != null and current_cell.unit == unit:
		current_cell.unit = null

	# If something already occupies the target, swap it to the vacated cell.
	if target_cell.unit != null and target_cell.unit != unit:
		var displaced = target_cell.unit

		displaced.position = current_cell.position
		current_cell.unit = displaced

	target_cell.unit = unit
	unit.position = target_cell.position
