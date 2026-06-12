extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var banner = (load("res://ui/cutin_banner.tscn") as PackedScene).instantiate()
	root.add_child(banner)

	for i in 5:
		await process_frame

	var events = root.get_node_or_null("/root/Events")
	var art: Texture2D = load("res://assets/terra/full/bahl_full.png")

	print("events=", events, " art=", art != null)

	if events != null:
		events.emit_signal("cutin_requested", [art], "Chain x3", true, Color.WHITE)

	for i in 20:
		await process_frame

	root.get_texture().get_image().save_png("/tmp/tb_polish/cutin_test.png")

	print("banner visible=", banner.visible, " label=", banner.get_node("Band/NameLabel").text, " band_size=", banner.get_node("Band").size)

	quit(0)
