extends SceneTree
# Dev tool: renders the companion equip screen for the first roster unit, with a
# couple of companions owned and coins to spare (in memory only, never saved).
#   godot --path . --script res://tools/shot_companion.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var gd = root.get_node("/root/GameData")
	gd.load_data()

	gd.save_data.coins = 1500
	gd.save_data.add_owned_companion("res://companions/resources/terra/striker_module.tres")

	var job = gd.save_data.jobs[0]

	var menu = load("res://ui/companion_equip_menu.tscn").instantiate()
	root.add_child(menu)
	menu.on_add_to_tree(job)

	for i in 90:
		await process_frame

	root.get_texture().get_image().save_png("/tmp/companion_shot.png")
	print("SHOT SAVED")

	quit(0)
