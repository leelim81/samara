extends SceneTree
# Dev tool: shows the guided tutorial's three forced moves over a live battle
# and screenshots each (callout + bouncing grab arrow + pulsing drop ring):
#   1  pincer      2  chain line-up      3  chain trap
# Run windowed:
#   godot --path . --script res://tools/shot_tutorial.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Force a fresh 3-hero squad so the chain moves (which need 3) show.
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

	# MOVE 1 (pincer): let the layout settle, then shoot.
	await _await_text(guide, "TUT_PINCER_MOVE")
	for i in 12:
		await process_frame
	_shoot("/tmp/tutorial_shot.png")

	# Resolve move 1 -> explanation -> chain line-up. Advancement rides the
	# player_turn_started latch, and freeze keeps the board still.
	board.emit_signal("player_turn_started")
	await _await_text(guide, "TUT_PINCER_DONE")
	guide._tap_flag = true

	# MOVE 2 (chain line-up): drag a hero to the far side of the enemy.
	await _await_text(guide, "TUT_CHAIN_SETUP")
	for i in 12:
		await process_frame
	_shoot("/tmp/tutorial_shot2.png")

	# Resolve the line-up (no pincer) -> chain trap.
	board.emit_signal("player_turn_started")

	# MOVE 3 (chain trap): close the pincer so the lined-up hero chains in.
	await _await_text(guide, "TUT_CHAIN_MOVE")
	for i in 12:
		await process_frame
	_shoot("/tmp/tutorial_shot3.png")

	print("alive players: %d" % _count_alive(board._player_units_node))
	print("SHOTS SAVED")
	quit(0)


func _shoot(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)


func _await_text(guide, key: String, max_frames: int = 600) -> void:
	var f := 0
	while guide._text_label.text != tr(key) and f < max_frames:
		await process_frame
		f += 1


func _count_alive(units_node: Node) -> int:
	var n := 0
	for u in units_node.get_children():
		if u.is_alive():
			n += 1
	return n
