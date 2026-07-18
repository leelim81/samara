extends SceneTree
# Dev tool: renders the characters_menu populated from save data so the
# unit-row portrait framing and hover highlight can be inspected. Run windowed
# (NOT --headless):
#   godot --path . --script res://tools/shot_charmenu.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	# Force a fresh 3-hero squad so the list always populates.
	var default_save = load("res://save_data/default_save_data.tres")
	var sd = default_save.duplicate()
	sd.jobs = []
	for job in default_save.jobs:
		var j = job.duplicate()
		j.stats = j.stats.duplicate()
		j.source_path = job.source_path if job.source_path != "" else job.resource_path
		sd.jobs.push_back(j)
	sd.active_units = [0, 1, 2]
	root.get_node("/root/GameData").save_data = sd

	var menu = load("res://ui/pre_battle_menu/characters_menu.tscn").instantiate()
	root.add_child(menu)

	for i in 60:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/charmenu_shot.png")

	# Hover the first card so the new box highlight can be reviewed.
	var list = menu.get_node("MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer")
	if list.get_child_count() > 0:
		list.get_child(0)._on_Card_mouse_entered()

	for i in 20:
		await process_frame

	img = root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/charmenu_hover.png")

	print("SHOTS SAVED")
	quit(0)
