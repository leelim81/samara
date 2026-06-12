extends SceneTree
# Dev tool: renders a cutscene scene with a chapter resource assigned.
# Usage: godot --path . --script res://tools/screenshot_cutscene.gd -- <cutscene.tscn> <chapter.tres> <out.png> [frames]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()

	var scene_path: String = args[0]
	var chapter_path: String = args[1]
	var out_path: String = args[2]
	var wait_frames: int = int(args[3]) if args.size() > 3 else 150

	var cutscene = (load(scene_path) as PackedScene).instantiate()

	cutscene.chapter_data = load(chapter_path)

	root.add_child(cutscene)

	for i in wait_frames:
		await process_frame

	var image := root.get_texture().get_image()

	image.save_png(out_path)

	print("SCREENSHOT SAVED: %s" % out_path)

	quit(0)
