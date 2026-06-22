extends SceneTree
# Dev tool: loads a battle, forces a Powered Point spawn + lights 2 gauge
# segments, and screenshots so the HUD gauge + the teal P disc can be verified.
# Run WINDOWED (not --headless): godot --path . --script res://tools/shot_powerpoint.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var battle = load("res://battles/terra/borderlands.tscn").instantiate()
	root.add_child(battle)

	for i in 90:
		await process_frame

	var board = battle.get_node("Board")
	board._spawn_powered_point()
	board.emit_signal("power_changed", 2, board.POWER_MAX)

	for i in 30:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/powerpoint.png")
	print("SHOT SAVED")

	quit(0)
