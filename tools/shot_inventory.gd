extends SceneTree
# Dev tool: renders the inventory populated with a few materials (in memory only,
# never saved) so the card rows can be screenshotted.
#   godot --path . --script res://tools/shot_inventory.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var gd = root.get_node("/root/GameData")
	gd.load_data()

	gd.save_data.add_item("scrap", 12)
	gd.save_data.add_item("alloy", 5)
	gd.save_data.add_item("cell", 2)
	gd.save_data.add_item("sigil", 1)

	var menu = load("res://ui/inventory_menu.tscn").instantiate()
	root.add_child(menu)

	for i in 90:
		await process_frame

	root.get_texture().get_image().save_png("/tmp/inventory_shot.png")
	print("SHOT SAVED")

	quit(0)
