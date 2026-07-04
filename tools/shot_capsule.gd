extends SceneTree
# Dev tool: drops both capsule types on the board, screenshots the idle
# state, then collects them (with reward tags) and screenshots the burst.
# Run windowed: godot --path . --script res://tools/shot_capsule.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var battle = load("res://battles/terra/borderlands.tscn").instantiate()
	root.add_child(battle)

	for i in 90:
		await process_frame

	var board = battle.get_node("Board")
	var grid = board.get_node("Grid")

	var cells := [
		grid.get_cell_from_coordinates(Vector2(1, 5)),
		grid.get_cell_from_coordinates(Vector2(4, 5)),
	]
	var types := [Enums.CapsuleType.RECOVERY, Enums.CapsuleType.COIN]

	for i in 2:
		var cell = cells[i]
		cell.capsule_type = types[i]

		var disc: Node2D = board.CAPSULE_SCENE.instantiate()
		board._capsules_node.add_child(disc)
		disc.position = cell.position
		disc.initialize(types[i])
		board._capsule_discs[cell] = disc

	board._capsule_coin_amounts[cells[1]] = 86

	for i in 40:
		await process_frame

	root.get_viewport().get_texture().get_image().save_png("/tmp/capsules_idle.png")
	print("IDLE SHOT SAVED")

	board._clear_capsule(cells[0], "+HP")
	board._clear_capsule(cells[1], "+86 COINS")

	for i in 14:
		await process_frame

	root.get_viewport().get_texture().get_image().save_png("/tmp/capsules_burst.png")
	print("BURST SHOT SAVED")

	quit(0)
