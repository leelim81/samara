extends SceneTree
# Dev tool: loads a battle, waits for the player turn, screenshots the HUD so
# the drag-mode toggle (next to Pause / Fast-forward) can be inspected.
#   godot --path . --script res://tools/shot_hud.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")

	for i in 3000:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			break

	for i in 30:
		await process_frame

	root.get_texture().get_image().save_png("/tmp/hud_shot.png")
	print("SHOT SAVED")

	quit(0)
