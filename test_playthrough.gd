extends SceneTree
# Dev-only integration test: plays a whole stage by teleport-flanking enemies
# every player turn until victory. Exercises waves, enemy turns, skills,
# 2x2 boss pincers and the victory signal. Usage:
#   godot --headless --script res://test_playthrough.gd -- <battle_scene.tscn>


var _victory := false
var _defeat := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://battles/terra/borderlands.tscn"

	var battle = (load(scene_path) as PackedScene).instantiate()

	root.add_child(battle)

	var board = battle.get_node("Board")
	var grid = board.get_node("Grid")

	board.victory.connect(func(): _victory = true)
	board.defeat.connect(func(): _defeat = true)

	var rounds := 0

	for i in 12000:
		await process_frame

		if _victory:
			print("TEST PASS: victory after %d pincer rounds" % rounds)

			quit(0)

			return

		if _defeat:
			printerr("TEST FAIL: defeat after %d rounds" % rounds)

			quit(1)

			return

		if board._current_turn != board.Turn.PLAYER:
			continue

		# Wait a few frames so wave spawns and appear animations settle.
		for j in 20:
			await process_frame

		if _victory or _defeat:
			continue

		var enemy = _find_alive_enemy(board)

		if enemy == null:
			continue

		var players := _alive_players(board)

		if players.size() < 2:
			continue

		var flanks := _find_flank_cells(grid, enemy)

		if flanks.is_empty():
			printerr("TEST WARN: no flank found for %s" % enemy.name)

			continue

		_teleport(grid, players[0], flanks[0])
		_teleport(grid, players[1], flanks[1])

		rounds += 1

		print("TEST: round %d pincering %s (hp %d)" % [rounds, enemy.name, enemy.get_stats().health])

		await board._execute_pincers(players[0])

	printerr("TEST FAIL: timed out (rounds: %d, victory: %s)" % [rounds, _victory])

	quit(1)


func _alive_players(board) -> Array:
	var result := []

	for unit in board._player_units_node.get_children():
		if unit.is_alive():
			result.push_back(unit)

	return result


func _find_alive_enemy(board):
	for unit in board._enemy_units_node.get_children():
		if unit.is_alive() and not unit.is_escaped:
			return unit

	return null


func _find_flank_cells(grid, enemy) -> Array:
	var cell = grid.get_cell_from_position(enemy.position)

	if cell == null:
		return []

	var coordinates: Vector2 = cell.coordinates
	var width := 2 if enemy.is2x2() else 1

	# Horizontal flank: left of the body, right of the body (same row).
	var left: Vector2 = coordinates + Vector2(-1, 0)
	var right: Vector2 = coordinates + Vector2(width, 0)

	if grid._is_in_range(left) and grid._is_in_range(right):
		var left_cell = grid.get_cell_from_coordinates(left)
		var right_cell = grid.get_cell_from_coordinates(right)

		if _is_flankable(left_cell, enemy) and _is_flankable(right_cell, enemy):
			return [left_cell, right_cell]

	# Vertical flank: above and below (same column).
	var up: Vector2 = coordinates + Vector2(0, -1)
	var down: Vector2 = coordinates + Vector2(0, width)

	if grid._is_in_range(up) and grid._is_in_range(down):
		var up_cell = grid.get_cell_from_coordinates(up)
		var down_cell = grid.get_cell_from_coordinates(down)

		if _is_flankable(up_cell, enemy) and _is_flankable(down_cell, enemy):
			return [up_cell, down_cell]

	return []


# A cell can host a flanking ally if it's empty or holds a player unit.
func _is_flankable(cell, enemy) -> bool:
	if cell == null or cell.unit == enemy:
		return false

	return cell.unit == null or cell.unit.faction == 1


func _teleport(grid, unit, target_cell) -> void:
	var current_cell = grid.get_cell_from_position(unit.position)

	if target_cell == current_cell:
		return

	if current_cell != null and current_cell.unit == unit:
		current_cell.unit = null

	if target_cell.unit != null and target_cell.unit != unit:
		var displaced = target_cell.unit

		if current_cell != null:
			displaced.position = current_cell.position
			current_cell.unit = displaced

	target_cell.unit = unit
	unit.position = target_cell.position
