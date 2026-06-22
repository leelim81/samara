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

	var job = load("res://jobs/terra/daiana_job.tres").duplicate()
	job.stats = job.stats.duplicate()
	job.set_level(12)
	menu.initialize(job, 12)

	for i in 50:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/unitmenu_shot.png")
	print("SHOT SAVED")

	quit(0)
