extends SceneTree
# Verifies the K cheat: pressing K in a live battle instantly clears every
# enemy and fires victory.
#   godot --path . --script res://tools/probe_kwin.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")
	var victory := [false]

	board.victory.connect(func(): victory[0] = true)

	for i in 3000:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			break

	var before := 0
	for e in board._enemy_units_node.get_children():
		if e.is_alive():
			before += 1

	# Synthesize a K key press through the input system.
	var down := InputEventKey.new()
	down.keycode = KEY_K
	down.physical_keycode = KEY_K
	down.pressed = true
	Input.parse_input_event(down)

	await process_frame

	var up := InputEventKey.new()
	up.keycode = KEY_K
	up.physical_keycode = KEY_K
	up.pressed = false
	Input.parse_input_event(up)

	for i in 30:
		await process_frame

	print("ENEMIES ALIVE BEFORE K: %d" % before)
	print("VICTORY FIRED: %s" % victory[0])
	print("BATTLE OVER: %s" % board._battle_over)
	print("RESULT: %s" % ("PASS" if victory[0] and board._battle_over else "FAIL"))

	quit(0 if victory[0] else 1)
