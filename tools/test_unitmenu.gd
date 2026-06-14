extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DirAccess.make_dir_recursive_absolute("/tmp/tb_polish/unitmenu")
	var menu = (load("res://ui/view_unit_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	for i in 5: await process_frame
	var job = load("res://jobs/terra/kuscah_job.tres")
	job.level = 2
	menu.initialize(job, 2)
	for i in 25: await process_frame
	root.get_texture().get_image().save_png("/tmp/tb_polish/unitmenu/acolyte.png")
	# also a tall portrait (yachie)
	var job2 = load("res://jobs/animal_spirit/yachie_job.tres")
	menu.initialize(job2, 1)
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("/tmp/tb_polish/unitmenu/yachie.png")
	print("UNITMENU DONE")
	quit(0)
