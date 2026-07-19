extends SceneTree
# Visual capture harness for the Gallery (run NON-headless so it actually renders):
#   godot --script res://tools/shot_gallery.gd
# Saves screenshots of the title screen, the gallery list, and a hero detail page.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(720, 960)

	await _shoot("res://ui/main_menu/title_screen.tscn", null, "/tmp/_shot_title.png")
	await _shoot("res://ui/gallery_menu.tscn", null, "/tmp/_shot_gallery.png")

	var job = load("res://jobs/terra/amazora_job.tres").duplicate()
	job.source_path = "res://jobs/terra/amazora_job.tres"
	await _shoot("res://ui/gallery_detail_menu.tscn", job, "/tmp/_shot_detail.png")

	quit()


func _shoot(scene_path: String, data, out_path: String) -> void:
	var inst = load(scene_path).instantiate()
	root.add_child(inst)

	if data != null and inst.has_method("on_add_to_tree"):
		inst.on_add_to_tree(data)

	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw

	var img: Image = root.get_texture().get_image()
	img.save_png(out_path)
	print("shot %s  %s" % [out_path, str(img.get_size())])

	inst.queue_free()
	await process_frame
