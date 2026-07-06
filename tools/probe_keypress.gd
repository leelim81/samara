extends SceneTree
# Probe: synthesize EVERY letter/number/function/nav key in a live battle and
# report any that kill enemies or fire victory — proving no debug kill-all
# hotkey survives in the build.
#   godot --path . --script res://tools/probe_keypress.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")
	var victory_fired := [false]

	board.victory.connect(func(): victory_fired[0] = true)

	for i in 3000:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			break

	var before: int = _alive(board)

	# A-Z, 0-9, F1-F12, plus Enter/Space/Esc/Tab/Home/End/Delete/Backspace.
	var keys: Array = []
	for k in range(KEY_A, KEY_Z + 1):
		keys.append(k)
	for k in range(KEY_0, KEY_9 + 1):
		keys.append(k)
	for k in range(KEY_F1, KEY_F12 + 1):
		keys.append(k)
	keys.append_array([KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_TAB,
		KEY_HOME, KEY_END, KEY_DELETE, KEY_BACKSPACE])

	var offenders: Array = []

	for key in keys:
		var down := InputEventKey.new()
		down.keycode = key
		down.physical_keycode = key
		down.pressed = true
		Input.parse_input_event(down)

		await process_frame

		var up := InputEventKey.new()
		up.keycode = key
		up.physical_keycode = key
		up.pressed = false
		Input.parse_input_event(up)

		for i in 4:
			await process_frame

		if _alive(board) < before or victory_fired[0]:
			offenders.append(OS.get_keycode_string(key))
			break

	print("ENEMIES ALIVE BEFORE: %d, AFTER ALL KEYS: %d" % [before, _alive(board)])
	print("VICTORY FIRED: %s" % victory_fired[0])
	print("OFFENDING KEYS: %s" % ("none" if offenders.is_empty() else str(offenders)))
	print("RESULT: %s" % ("CLEAN" if offenders.is_empty() and not victory_fired[0] else "CHEAT PRESENT"))

	quit(0)


func _alive(board) -> int:
	var n := 0
	for e in board._enemy_units_node.get_children():
		if e.is_alive():
			n += 1
	return n
