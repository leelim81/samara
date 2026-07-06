extends SceneTree
# Dev tool: renders the characters_menu populated from save data so the
# unit-row portrait framing can be inspected. Run windowed (NOT --headless):
#   godot --path . --script res://tools/shot_charmenu.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var game_data = root.get_node("/root/GameData")
	game_data.load_data()

	var menu = load("res://ui/pre_battle_menu/characters_menu.tscn").instantiate()
	root.add_child(menu)

	for i in 60:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/charmenu_shot.png")
	print("SHOT SAVED")

	quit(0)
