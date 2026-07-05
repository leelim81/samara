extends SceneTree
# Dev tool: shows the themed New Ally overlay with two owned heroes.
#   godot --path . --script res://tools/shot_newally.gd -- <out.png>


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "/tmp/newally.png"

	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)

	for i in 90:
		await process_frame

	var game_data = root.get_node("/root/GameData")
	var jobs: Array = [game_data.save_data.jobs[0]]

	if game_data.save_data.jobs.size() > 1:
		jobs.push_back(game_data.save_data.jobs[1])

	battle._show_new_ally_dialog(jobs)

	for i in 20:
		await process_frame

	root.get_texture().get_image().save_png(out_path)
	print("SHOT SAVED: %s" % out_path)

	quit(0)
