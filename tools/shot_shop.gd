extends SceneTree
# Dev tool: renders the market with some coins so BUY buttons show both the
# affordable and unaffordable states (in memory only, never saved).
#   godot --path . --script res://tools/shot_shop.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var gd = root.get_node("/root/GameData")
	gd.load_data()

	gd.save_data.coins = 3500
	gd.save_data.add_item("scrap", 4)
	gd.save_data.add_item("cell", 1)

	var menu = load("res://ui/shop/shop_menu.tscn").instantiate()
	root.add_child(menu)

	for i in 90:
		await process_frame

	root.get_texture().get_image().save_png("/tmp/shop_shot.png")
	print("SHOT SAVED")

	quit(0)
