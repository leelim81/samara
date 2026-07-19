extends SceneTree
# Regenerates bestiary/gallery_list.tres by scanning jobs/terra for EVERY unit
# (heroes and enemies) for the debug Gallery screen. Heroes are non-MONSTER,
# non-HANIWA units; enemies are MONSTER/HANIWA (same rule as build_bestiary.gd).
# Each entry is a lightweight Dictionary of strings/ints so the gallery list
# renders without loading the large full-art portraits — the full art is loaded
# only when a unit's detail page is opened. Re-run whenever the roster changes:
#   godot --headless --script res://tools/build_gallery.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var entries := []

	var dir := DirAccess.open("res://jobs/terra")

	if dir == null:
		push_error("build_gallery: cannot open res://jobs/terra")
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
		var is_enemy: bool = unit_type == "MONSTER" or unit_type == "HANIWA"

		entries.append({
			"path": path,
			"name_key": job.job_name,
			"token_path": job.portrait.resource_path if job.portrait != null else "",
			"unit_type": unit_type,
			"is_enemy": is_enemy,
		})

	# Heroes first (alphabetical), then enemies (alphabetical), so the two
	# gallery sections come out already ordered.
	entries.sort_custom(func(a, b):
		if a["is_enemy"] != b["is_enemy"]:
			return not a["is_enemy"]
		return String(a["name_key"]) < String(b["name_key"]))

	var list = load("res://bestiary/bestiary_list.gd").new()
	list.entries = entries

	var error := ResourceSaver.save(list, "res://bestiary/gallery_list.tres")

	var heroes := entries.filter(func(e): return not e["is_enemy"]).size()

	if error == OK:
		print("build_gallery: wrote %d units (%d heroes, %d enemies)" % [entries.size(), heroes, entries.size() - heroes])
	else:
		push_error("build_gallery: save failed (%d)" % error)

	quit(0 if error == OK else 1)
