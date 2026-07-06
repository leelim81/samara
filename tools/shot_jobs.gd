extends SceneTree
# Dev tool: renders the jobs screen for the first roster unit with job 2 unlocked
# and active, so all three states show at once (job 1 switchable, job 2 active,
# job 3 unlockable with cost). Coins/materials granted in memory only, never saved.
#   godot --path . --script res://tools/shot_jobs.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var gd = root.get_node("/root/GameData")
	gd.load_data()

	gd.save_data.coins = 20000
	gd.save_data.add_item("alloy", 10)
	gd.save_data.add_item("core", 5)

	var job = gd.save_data.jobs[0]

	if job.source_path == "":
		job.source_path = "res://jobs/terra/bahl_job.tres"

	job.unlock_next_job()  # unlock job 2 and make it active

	var menu = load("res://ui/job_menu.tscn").instantiate()
	root.add_child(menu)
	menu.on_add_to_tree(job)

	for i in 90:
		await process_frame

	root.get_texture().get_image().save_png("/tmp/jobs_shot.png")
	print("SHOT SAVED")

	quit(0)
