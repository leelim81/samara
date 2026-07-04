extends SceneTree
# Dev tool: renders the chain-preview link by driving the real previewer with
# a unit and a cell that has allies in line. Run windowed:
#   godot --path . --script res://tools/shot_chain.gd -- <out.png>


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "/tmp/chain.png"

	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")

	for i in 3000:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			break

	# Line the squad up so a chain preview forms: three allies on row 4,
	# preview from the middle unit's cell.
	var grid = board.get_node("Grid")
	var units: Array = board.get_player_units()
	var previewer = board.get_node("ChainPreviewer")

	var cells := []

	for i in units.size():
		var coords := Vector2(i * 2, 4)
		var origin: Vector2 = grid.cell_coordinates_to_cell_origin(coords)
		units[i].position = origin
		var cell = grid.get_cell_from_coordinates(coords)
		cell.unit = units[i]
		cells.push_back(cell)

	await process_frame

	previewer.update_preview(units[0], cells[0])

	for i in 20:
		await process_frame

	root.get_texture().get_image().save_png(out_path)
	print("SHOT SAVED: %s" % out_path)

	quit(0)
