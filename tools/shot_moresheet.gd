extends SceneTree
# Dev tool: opens the hub's More bottom sheet and screenshots it. Run
# windowed (NOT --headless):
#   godot --path . --script res://tools/shot_moresheet.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hub = (load("res://ui/pre_battle_menu/pre_battle_menu.tscn") as PackedScene).instantiate()
	root.add_child(hub)

	for i in 40:
		await process_frame

	hub._on_MoreButton_pressed()

	for i in 30:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/moresheet_shot.png")
	print("SHOT SAVED")

	quit(0)
