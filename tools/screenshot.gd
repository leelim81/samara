extends SceneTree
# Dev tool: loads a scene, waits a number of frames, saves a screenshot, quits.
# Usage:
#   godot --path . --script res://tools/screenshot.gd -- <scene.tscn> <out.png> [frames]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()

	var scene_path: String = args[0] if args.size() > 0 else "res://ui/main_menu/title_screen.tscn"
	var out_path: String = args[1] if args.size() > 1 else "/tmp/shot.png"
	var wait_frames: int = int(args[2]) if args.size() > 2 else 90

	var packed: PackedScene = load(scene_path)

	if packed == null:
		printerr("Failed to load scene %s" % scene_path)

		quit(1)

		return

	root.add_child(packed.instantiate())

	for i in wait_frames:
		await process_frame

	var image := root.get_texture().get_image()

	image.save_png(out_path)

	print("SCREENSHOT SAVED: %s" % out_path)

	quit(0)
