extends SceneTree
# Dev tool: renders the view_unit_menu populated with a job so the status
# screen (element + EXP) can be screenshotted. Run windowed (NOT --headless):
#   godot --path . --script res://tools/shot_unitmenu.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var menu = load("res://ui/view_unit_menu.tscn").instantiate()
	root.add_child(menu)

	await process_frame
	await process_frame

	var game_data = root.get_node("/root/GameData")
	game_data.load_data()

	var job = game_data.save_data.jobs[0]
	menu.initialize(job, job.level)

	for i in 50:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/unitmenu_shot.png")
	print("SHOT SAVED")

	quit(0)
