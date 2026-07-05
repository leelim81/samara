extends SceneTree
# Dev tool: renders a unit detail whose skills carry an earned Skill Boost so the
# cyan "+X%" indicator can be screenshotted (in memory only, never saved).
#   godot --path . --script res://tools/shot_skillboost.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var gd = root.get_node("/root/GameData")
	gd.load_data()

	var menu = load("res://ui/view_unit_menu.tscn").instantiate()
	root.add_child(menu)

	await process_frame
	await process_frame

	var job = gd.save_data.jobs[0]
	job.level = 90

	for _n in 40:
		job.register_skill_use(0)
	for _n in 8:
		job.register_skill_use(1)

	menu.initialize(job, 90)

	for i in 60:
		await process_frame

	root.get_viewport().get_texture().get_image().save_png("/tmp/skillboost_shot.png")
	print("SHOT SAVED")

	quit(0)
