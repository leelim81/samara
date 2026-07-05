extends SceneTree
# Probe: pincer-kill EVERY wave-1 enemy in one player action and log the
# order of victory / enemy_phase_started signals, to catch victory firing
# while later waves still remain.
#   godot --headless --script res://tools/probe_wave_victory.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")
	var grid = board.get_node("Grid")
	var log := []

	board.victory.connect(func(): log.push_back("VICTORY signal (phase %d/%d)" % [board._current_enemy_phase, board._enemy_phase_count]))
	board.enemy_phase_started.connect(func(cur, total): log.push_back("phase_started %d/%d" % [cur, total]))

	for i in 3000:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			break

	# Zero every wave-1 enemy's HP but one, then pincer the last one so the
	# executor's death pipeline clears the whole wave in one resolution.
	var enemies: Array = board._enemy_units_node.get_children()

	log.push_back("wave %d/%d has %d enemies" % [board._current_enemy_phase, board._enemy_phase_count, enemies.size()])

	for i in range(1, enemies.size()):
		enemies[i].inflict_damage(enemies[i].get_stats().health - 1)

	var target = enemies[0]

	for other in range(1, enemies.size()):
		enemies[other].inflict_damage(2)

	var players := []

	for unit in board._player_units_node.get_children():
		if unit.is_alive():
			players.push_back(unit)

	var cell = grid.get_cell_from_position(target.position)
	var left = grid.get_cell_from_coordinates(cell.coordinates + Vector2(-1, 0))
	var right = grid.get_cell_from_coordinates(cell.coordinates + Vector2(1, 0))

	_teleport(grid, players[0], left)
	_teleport(grid, players[1], right)

	board._execute_pincers(players[0])

	for i in 900:
		await process_frame

	log.push_back("end: phase %d/%d, children %d, turn %d" % [
		board._current_enemy_phase, board._enemy_phase_count,
		board._enemy_units_node.get_children().size(), board._current_turn])

	for entry in log:
		print("PROBE: ", entry)

	quit(0)


func _teleport(grid, unit, target_cell) -> void:
	var current_cell = grid.get_cell_from_position(unit.position)

	if target_cell == current_cell:
		return

	if current_cell != null and current_cell.unit == unit:
		current_cell.unit = null

	unit.position = target_cell.position
	target_cell.unit = unit
