extends SceneTree
# Dev tool: shows the guided tutorial's first step over a live battle and
# screenshots it (callout plate + pulsing ring on a hero). Run windowed:
#   godot --path . --script res://tools/shot_tutorial.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	var board = battle.get_node("Board")

	for i in 1200:
		await process_frame
		if board._current_turn == board.Turn.PLAYER:
			break

	# Runtime-load (not the TutorialGuide class_name): a compile-time class
	# reference would force the script to compile before autoloads register in
	# this --script tool, breaking its GameData reference.
	var guide = load("res://ui/tutorial_guide.gd").new()
	guide.setup(board, battle)
	battle.add_child(guide)

	# Let _ready rearrange the board and settle the forced-drag step.
	for i in 40:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/tutorial_shot.png")

	# Advance to the explanation step for a second capture.
	root.get_node("/root/Events").emit_signal("cutin_requested", [null], "", true, Color.WHITE, false)

	for i in 20:
		await process_frame

	img = root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/tutorial_shot2.png")

	print("SHOTS SAVED")
	quit(0)
