extends SceneTree
# Dev tool: loads a battle, flanks the first enemy, runs the real pincer
# pipeline and saves a burst of frames so the attack animations can be
# reviewed. Needs a window (rendering) — do not run with --headless.
# Usage:
#   godot --path . --script res://tools/screenshot_pincer.gd -- <out_dir> [battle.tscn]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()

	var out_dir: String = args[0] if args.size() > 0 else "/tmp/pincer_frames"
	var scene_path: String = args[1] if args.size() > 1 else "res://battles/terra/borderlands.tscn"

	DirAccess.make_dir_recursive_absolute(out_dir)

	var battle = (load(scene_path) as PackedScene).instantiate()

	root.add_child(battle)

	var board = battle.get_node("Board")
	var grid = board.get_node("Grid")

	for i in 1200:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			break

	if board._current_turn != board.Turn.PLAYER:
		printerr("CAPTURE FAIL: player turn never started")

		quit(1)

		return

	# Extra frames so appear animations settle
	for i in 30:
		await process_frame

	var enemy = null

	for candidate in board._enemy_units_node.get_children():
		if candidate.is_alive() and not candidate.is2x2():
			enemy = candidate

			break

	if enemy == null:
		printerr("CAPTURE FAIL: no enemy found")

		quit(1)

		return

	var players := []

	for unit in board._player_units_node.get_children():
		if unit.is_alive():
			players.push_back(unit)

	var cell = grid.get_cell_from_position(enemy.position)
	var left = grid.get_cell_from_coordinates(cell.coordinates + Vector2(-1, 0))
	var right = grid.get_cell_from_coordinates(cell.coordinates + Vector2(1, 0))

	if left == null or right == null:
		printerr("CAPTURE FAIL: enemy not flankable")

		quit(1)

		return

	_teleport(grid, players[0], left)
	_teleport(grid, players[1], right)

	# Build a chain: ally directly below the left flanker
	var below = grid.get_cell_from_coordinates(left.coordinates + Vector2(0, 1))

	if below != null and players.size() > 2:
		_teleport(grid, players[2], below)

	board._execute_pincers(players[0])

	# Capture a strip of frames while the pincer resolves
	var shot := 0

	for i in 240:
		await process_frame

		if i % 8 == 0:
			var image := root.get_texture().get_image()

			image.save_png("%s/frame_%03d.png" % [out_dir, shot])

			shot += 1

	print("CAPTURE DONE: %d frames in %s" % [shot, out_dir])

	quit(0)


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
