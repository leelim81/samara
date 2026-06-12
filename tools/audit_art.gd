extends SceneTree
# Dev tool: renders every job's tile token next to its full art so
# mismatched pairings are obvious at a glance. Needs a window.
# Usage:
#   godot --path . --script res://tools/audit_art.gd --windowed -- <out.png>


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)

	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "/tmp/art_audit.png"

	var job_paths := []

	for dir_name in ["res://jobs/terra", "res://jobs/animal_spirit", "res://jobs/haniwa"]:
		var dir := DirAccess.open(dir_name)

		if dir == null:
			continue

		for file in dir.get_files():
			if file.ends_with(".tres"):
				job_paths.push_back(dir_name + "/" + file)

	job_paths.sort()

	var viewport := SubViewport.new()

	viewport.size = Vector2i(740, 1260)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var canvas := Control.new()

	canvas.anchor_right = 1.0
	canvas.anchor_bottom = 1.0

	var bg := ColorRect.new()

	bg.color = Color(0.93, 0.91, 0.85)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	canvas.add_child(bg)

	viewport.add_child(canvas)

	var columns := 4
	var cell_w := 178.0
	var cell_h := 200.0

	for i in job_paths.size():
		var job = load(job_paths[i])

		var x: float = 8.0 + (i % columns) * cell_w
		var y: float = 8.0 + (i / columns) * cell_h

		var token := TextureRect.new()

		token.texture = job.portrait
		token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		token.position = Vector2(x, y)
		token.size = Vector2(72, 72)
		canvas.add_child(token)

		var full := TextureRect.new()

		full.texture = job.full_portrait
		full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		full.position = Vector2(x + 78, y)
		full.size = Vector2(90, 150)
		canvas.add_child(full)

		var label := Label.new()

		label.text = job_paths[i].get_file().replace("_job.tres", "")
		label.position = Vector2(x, y + 156)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		canvas.add_child(label)

	for i in 25:
		await process_frame

	viewport.get_texture().get_image().save_png(out_path)

	print("AUDIT SAVED: %s (%d jobs)" % [out_path, job_paths.size()])

	quit(0)
