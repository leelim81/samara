extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DirAccess.make_dir_recursive_absolute("/tmp/tb_polish/slice2")
	var bg = ColorRect.new(); bg.color = Color(0.90,0.87,0.80); bg.size=Vector2(720,960); root.add_child(bg)
	var boss = (load("res://units/enemies/terra/spinetrich.tscn") as PackedScene).instantiate()
	boss.position = Vector2(300,380); root.add_child(boss)
	for i in 10: await process_frame
	boss.get_stats().health = 0; boss.play_death_animation()
	var shot=0
	for i in 100:
		await process_frame
		if i % 9 == 0: root.get_texture().get_image().save_png("/tmp/tb_polish/slice2/f%02d.png" % shot); shot+=1
	print("SLICE2 DONE")
	quit(0)
