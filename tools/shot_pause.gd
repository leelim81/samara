extends SceneTree
# Dev tool: loads a battle, waits for the player turn, opens the pause menu,
# saves a screenshot. Run windowed:
#   godot --path . --script res://tools/shot_pause.gd -- <out.png>


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "/tmp/pause.png"

	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")

	for i in 3000:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			break

	battle._open_pause_menu()

	for i in 30:
		await process_frame

	root.get_texture().get_image().save_png(out_path)
	print("SHOT SAVED: %s" % out_path)

	quit(0)
