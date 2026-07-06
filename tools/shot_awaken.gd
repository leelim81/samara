extends SceneTree
# Dev tool: renders a unit detail where Awaken is available (owned, level 50, a
# Neural Core + coins on hand), in memory only.
#   godot --path . --script res://tools/shot_awaken.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var gd = root.get_node("/root/GameData")
	gd.load_data()
	gd.save_data.coins = 5000
	gd.save_data.add_item("core", 2)

	var menu = load("res://ui/view_unit_menu.tscn").instantiate()
	root.add_child(menu)

	await process_frame
	await process_frame

	var job = gd.save_data.jobs[0]
	job.level = 50
	job.metamorphose()
	menu.initialize(job, 50)

	for i in 60:
		await process_frame

	root.get_viewport().get_texture().get_image().save_png("/tmp/awakened_form.png")
	print("SHOT SAVED")

	quit(0)
