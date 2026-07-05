extends SceneTree
# Regenerates bestiary/enemy_list.tres by scanning jobs/terra for enemy units
# (unit_type MONSTER or HANIWA) and pairing each with a representative battle
# level read from the enemy scenes in units/enemies/terra. Re-run whenever the
# enemy roster or their levels change:
#   godot --headless --script res://tools/build_bestiary.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level_by_job := _scan_enemy_levels()

	var entries := []

	var dir := DirAccess.open("res://jobs/terra")

	if dir == null:
		push_error("build_bestiary: cannot open res://jobs/terra")
		quit(1)
		return

	var files := dir.get_files()
	files.sort()

	for file in files:
		if not file.ends_with("_job.tres"):
			continue

		var path := "res://jobs/terra/" + file
		var job = load(path)

		if job == null or job.stats == null:
			continue

		var unit_type: String = job.stats.unit_type

		if unit_type != "MONSTER" and unit_type != "HANIWA":
			continue

		entries.append({
			"path": path,
			"name_key": job.job_name,
			"token_path": job.portrait.resource_path if job.portrait != null else "",
			"weapon_type": int(job.stats.weapon_type),
			"attribute": int(job.stats.attribute),
			"level": int(level_by_job.get(path, 1)),
		})

	entries.sort_custom(func(a, b): return String(a["name_key"]) < String(b["name_key"]))

	var list = load("res://bestiary/bestiary_list.gd").new()
	list.entries = entries

	var error := ResourceSaver.save(list, "res://bestiary/enemy_list.tres")

	if error == OK:
		print("build_bestiary: wrote %d enemies" % entries.size())
	else:
		push_error("build_bestiary: save failed (%d)" % error)

	quit(0 if error == OK else 1)


# Text-scans the enemy scenes for their job path and battle level (the level is
# set on the enemy node, not the job resource). Returns job_path -> max level.
func _scan_enemy_levels() -> Dictionary:
	var map := {}

	var dir := DirAccess.open("res://units/enemies/terra")

	if dir == null:
		return map

	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue

		var text := FileAccess.get_file_as_string("res://units/enemies/terra/" + file)

		if text == "":
			continue

		var job_path := ""
		var level := 0

		for raw in text.split("\n"):
			var line := raw.strip_edges()

			if job_path == "" and line.begins_with("[ext_resource") and "jobs/terra/" in line and "_job.tres" in line:
				var marker := "path=\""
				var p := line.find(marker)

				if p != -1:
					var start := p + marker.length()
					var stop := line.find("\"", start)

					if stop != -1:
						job_path = line.substr(start, stop - start)
			elif level == 0 and line.begins_with("level = "):
				level = int(line.substr("level = ".length()))

		if job_path != "" and level > int(map.get(job_path, 0)):
			map[job_path] = level

	return map
