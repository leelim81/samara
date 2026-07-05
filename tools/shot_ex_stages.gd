extends SceneTree
# Dev tool: renders the pre-battle hub with a high account rank so the EX stages
# section is visible, scrolled to the bottom (in memory only, never saved).
#   godot --path . --script res://tools/shot_ex_stages.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var gd = root.get_node("/root/GameData")
	gd.load_data()
	gd.save_data.account_exp = 3000

	var menu = load("res://ui/pre_battle_menu/pre_battle_menu.tscn").instantiate()
	root.add_child(menu)

	for i in 40:
		await process_frame

	var scroll = menu.get_node("MarginContainer/VBoxContainer/ScrollContainer")
	scroll.scroll_vertical = 99999

	for i in 30:
		await process_frame

	root.get_texture().get_image().save_png("/tmp/ex_stages.png")
	print("SHOT SAVED")

	quit(0)
