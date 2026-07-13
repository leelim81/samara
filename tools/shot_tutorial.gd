extends SceneTree
# Dev tool: shows the guided tutorial's first step over a live battle and
# screenshots it (callout plate + pulsing ring on a hero). Run windowed:
#   godot --path . --script res://tools/shot_tutorial.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Force a fresh 3-hero squad so the chain move (needs 3) shows.
	var default_save = load("res://save_data/default_save_data.tres")
	var sd = default_save.duplicate()
	sd.jobs = []
	for job in default_save.jobs:
		var j = job.duplicate()
		j.stats = j.stats.duplicate()
		j.source_path = job.source_path if job.source_path != "" else job.resource_path
		sd.jobs.push_back(j)
	sd.active_units = [0, 1, 2]
	root.get_node("/root/GameData").save_data = sd

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

	# Let _ready rearrange the board and settle the pincer move (arrow + ring).
	for i in 40:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/tutorial_shot.png")

	# Advance past the pincer to the chain move: fire the pincer cut-in, then a
	# player turn so the guide sets up the chain layout.
	var events = root.get_node("/root/Events")
	events.emit_signal("cutin_requested", [null], "", true, Color.WHITE, false)
	for i in 8:
		await process_frame
	# Tap through the explanation instead of waiting out its timer.
	guide._on_callout_tapped()
	for i in 4:
		await process_frame
	board.emit_signal("player_turn_started")
	for i in 30:
		await process_frame
	print("alive players: %d" % _count_alive(board._player_units_node))

	img = root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/tutorial_shot2.png")

	print("SHOTS SAVED")
	quit(0)


func _count_alive(units_node: Node) -> int:
	var n := 0
	for u in units_node.get_children():
		if u.is_alive():
			n += 1
	return n
