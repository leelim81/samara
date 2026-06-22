extends SceneTree
# Instantiates each given enemy scene (running _ready, which validate_check skips)
# to surface runtime errors like the apply_equip_skills texture access.
# Usage: godot --headless --script res://tools/find_bad_enemy.gd -- <slug> <slug> ...


func _initialize() -> void:
	var slugs := OS.get_cmdline_user_args()

	for slug in slugs:
		print("--- instantiating %s" % slug)

		var scene: PackedScene = load("res://units/enemies/terra/%s.tscn" % slug)

		if scene == null:
			printerr("  could not load %s" % slug)
			continue

		var enemy: Node = scene.instantiate()
		root.add_child(enemy)

		await process_frame

		enemy.queue_free()

		await process_frame

	print("--- done")
	quit()
