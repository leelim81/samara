extends SceneTree
# Dev tool: renders the bestiary with a few enemies marked discovered (in memory
# only, never saved) so the screenshot shows discovered + undiscovered states.
#   godot --path . --script res://tools/shot_bestiary.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var gd = root.get_node("/root/GameData")
	gd.load_data()

	var manifest = load("res://bestiary/enemy_list.tres")
	var entries: Array = manifest.entries

	# Discover a spread of entries so the shot shows defeated / seen / locked.
	if entries.size() > 0:
		gd.save_data.mark_enemy_defeated(entries[0]["path"])
	if entries.size() > 1:
		gd.save_data.mark_enemy_defeated(entries[1]["path"])
	if entries.size() > 3:
		gd.save_data.mark_enemy_seen(entries[3]["path"])

	var menu = load("res://ui/bestiary_menu.tscn").instantiate()
	root.add_child(menu)

	for i in 90:
		await process_frame

	var img := root.get_texture().get_image()
	img.save_png("/tmp/bestiary_shot.png")
	print("SHOT SAVED")

	quit(0)
