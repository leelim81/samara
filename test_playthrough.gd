extends SceneTree
# Integration smoke test: drives a battle to victory by teleport-pincering enemies.
# Each player turn it finds any enemy with two naturally-free flank cells (never
# displacing other enemies, which would corrupt the board) and sandwiches it with
# two strikers. Fails fast if no enemy is flankable for many turns.
#
# NOTE: this is a smoke test, not a guaranteed oracle. A single-pincer teleport
# bot cannot clear every chapter (clustered enemies with no free flanks, or very
# tanky 2x2 bosses). A true 38/38 gate would need to drive the engine's real
# one-unit-drag move API. Use validate_check.gd for the authoritative load gate.
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
	var no_flank_streak := 0

	for i in 20000:
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

		# Let wave spawns / appear animations settle.
		for j in 20:
			await process_frame

		if _victory or _defeat:
			continue

		var players := _alive_players(board)

		if players.size() < 2:
			continue

		# Find any alive enemy with two naturally-free flank cells.
		var flanks := []

		for enemy in _alive_enemies(board):
			var f := _find_flank_cells(grid, enemy)

			if not f.is_empty():
				flanks = f
				break

		if flanks.is_empty():
			no_flank_streak += 1

			if no_flank_streak > 40:
				printerr("TEST FAIL: no flankable enemy for 40 turns (rounds: %d)" % rounds)
				quit(1)
				return

			continue

		no_flank_streak = 0

		_teleport(grid, players[0], flanks[0])
		_teleport(grid, players[1], flanks[1])

		rounds += 1

		await board._execute_pincers(players[0])

	printerr("TEST FAIL: timed out (rounds: %d, victory: %s)" % [rounds, _victory])
	quit(1)


func _alive_players(board) -> Array:
	var result := []

	for unit in board._player_units_node.get_children():
		if unit.is_alive():
			result.push_back(unit)

	return result


func _alive_enemies(board) -> Array:
	var result := []

	for unit in board._enemy_units_node.get_children():
		if unit.is_alive() and not unit.is_escaped:
			result.push_back(unit)

	return result


# Two free, in-range cells on opposite sides of the enemy (horizontal, then
# vertical). Spans the 2-wide body for 2x2 bosses. A cell is free if empty or
# holds a player (we never displace enemies).
func _find_flank_cells(grid, enemy) -> Array:
	var cell = _cell_of(grid, enemy)

	if cell == null:
		return []

	var c: Vector2 = cell.coordinates
	var w := 2 if enemy.is2x2() else 1

	var pairs := [
		[c + Vector2(-1, 0), c + Vector2(w, 0)],
		[c + Vector2(0, -1), c + Vector2(0, w)],
	]

	for pair in pairs:
		if grid._is_in_range(pair[0]) and grid._is_in_range(pair[1]):
			var a = grid.get_cell_from_coordinates(pair[0])
			var b = grid.get_cell_from_coordinates(pair[1])

			if _is_free(a, enemy) and _is_free(b, enemy):
				return [a, b]

	return []


func _is_free(cell, enemy) -> bool:
	if cell == null or cell.unit == enemy:
		return false

	return cell.unit == null or cell.unit.faction == 1


# Authoritative cell of a unit (the cell that actually holds it), robust to pixel
# position drift after teleports.
func _cell_of(grid, unit):
	for x in grid.width:
		for y in grid.height:
			var cell = grid.get_cell_from_coordinates(Vector2(x, y))

			if cell != null and cell.unit == unit:
				return cell

	return null


func _teleport(grid, unit, target_cell) -> void:
	if target_cell == null:
		return

	var current_cell = _cell_of(grid, unit)

	if current_cell == target_cell:
		return

	# Target cells are always empty or player-held, so any displaced unit is a
	# player swapped into the striker's old cell — enemies are never orphaned.
	var displaced = target_cell.unit

	if current_cell != null:
		current_cell.unit = displaced

		if displaced != null:
			displaced.position = current_cell.position

	target_cell.unit = unit
	unit.position = target_cell.position
