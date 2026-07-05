extends SceneTree
# Probe: synthesize K (and Home) presses in a live battle and report what
# reacts — hunting the reported kill-all-enemies hotkey.
#   godot --script res://tools/probe_keypress.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")
	var events := []

	board.victory.connect(func(): events.push_back("VICTORY"))
	board.enemy_phase_started.connect(func(c, t): events.push_back("phase %d/%d" % [c, t]))

	for i in 3000:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			break

	var before: int = board._enemy_units_node.get_children().size()

	for key in [KEY_K, KEY_HOME]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = true
		Input.parse_input_event(ev)

		await process_frame

		var up := InputEventKey.new()
		up.keycode = key
		up.physical_keycode = key
		up.pressed = false
		Input.parse_input_event(up)

		for i in 60:
			await process_frame

		var alive := 0

		for e in board._enemy_units_node.get_children():
			if e.is_alive():
				alive += 1

		print("PROBE after key %s: enemies in node %d (alive %d), events %s, debug_build=%s" % [
			OS.get_keycode_string(key), board._enemy_units_node.get_children().size(), alive, events, OS.is_debug_build()])

	quit(0)
