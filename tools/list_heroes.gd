extends SceneTree
# Dumps hero jobs (non-MONSTER/HANIWA) with names, bios, and portrait paths to
# /tmp/heroes.json, for the awakened-placeholder generator + manifest.
#   godot --headless --script res://tools/list_heroes.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var dir := DirAccess.open("res://jobs/terra")
	var heroes := []

	for file in dir.get_files():
		if not file.ends_with("_job.tres"):
			continue

		var job = load("res://jobs/terra/" + file)

		if job == null or job.stats == null:
			continue

		var unit_type: String = job.stats.unit_type

		if unit_type == "MONSTER" or unit_type == "HANIWA":
			continue

		heroes.append({
			"slug": file.replace("_job.tres", ""),
			"name": tr(job.job_name),
			"description": job.description,
			"full": job.full_portrait.resource_path if job.full_portrait != null else "",
			"token": job.portrait.resource_path if job.portrait != null else "",
		})

	heroes.sort_custom(func(a, b): return a["slug"] < b["slug"])

	var out := FileAccess.open("/tmp/heroes.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(heroes, "  "))
	out.close()

	print("wrote %d heroes" % heroes.size())
	quit(0)
