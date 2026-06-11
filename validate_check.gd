extends SceneTree
# Dev-only validation: force-loads every script, scene and resource in the
# project to surface parse errors and broken references. Run with:
# godot --headless --script res://validate_check.gd


func _initialize() -> void:
	var files: Array[String] = []
	_walk("res://", files)

	var failures: int = 0
	var checked: int = 0

	for path in files:
		if path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres"):
			checked += 1

			var resource: Resource = ResourceLoader.load(path)

			if resource == null:
				failures += 1
				printerr("FAILED TO LOAD: %s" % path)
			elif resource is PackedScene and not path.begins_with("res://addons"):
				var instance := (resource as PackedScene).instantiate()

				if instance == null:
					failures += 1
					printerr("FAILED TO INSTANTIATE: %s" % path)
				else:
					instance.free()

	print("validate_check: checked %d files, %d load failures" % [checked, failures])

	quit(1 if failures > 0 else 0)


func _walk(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)

	if dir == null:
		return

	dir.list_dir_begin()

	var entry := dir.get_next()

	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()

			continue

		var full_path := path.path_join(entry)

		if dir.current_is_dir():
			_walk(full_path, out)
		else:
			out.push_back(full_path)

		entry = dir.get_next()

	dir.list_dir_end()
