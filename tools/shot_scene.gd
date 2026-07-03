extends SceneTree
# Generic windowed screenshotter: loads a scene, waits, saves a PNG.
#   godot --path . --script res://tools/shot_scene.gd -- <scene.tscn> <out.png> [frames]
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0]
	var out_path: String = args[1]
	var frames: int = int(args[2]) if args.size() > 2 else 90
	var node = (load(scene_path) as PackedScene).instantiate()
	root.add_child(node)
	for i in frames:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_path)
	print("SHOT SAVED: %s" % out_path)
	quit(0)
