extends SceneTree
# Dev tool: loads a battle, kills all enemies to force victory, captures the
# results screen after the count-up. Needs a window.
# Usage: godot --path . --script res://tools/screenshot_victory.gd --windowed -- <out_dir>


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)

	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/victory"

	DirAccess.make_dir_recursive_absolute(out_dir)

	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")

	for i in 3000:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			break

	# Simulate spoils as if a wave was cleared, then trigger victory
	board._battle_exp = 0
	board._battle_coins = 0
	board._enemies_defeated = 0

	for enemy in board._enemy_units_node.get_children():
		board._accumulate_spoils(enemy)

	# Add a couple more kills for a fuller tally
	for i in 4:
		board._battle_exp += 90
		board._battle_coins += 40
		board._enemies_defeated += 1

	battle._total_drag_time_seconds = 27.4
	battle._player_turn_count = 5

	board.emit_signal("victory")

	# SceneTreeTimers don't tick reliably under the --script harness, so the
	# game's 1.5s "let the death dissolve finish" await can hang here. Give it
	# 100 frames, then force the overlay like _on_Board_victory would.
	var victory_screen = battle.get_node("CanvasLayer/VictoryScreen")

	for i in 100:
		await process_frame

		if victory_screen.visible:
			break

	if not victory_screen.visible:
		victory_screen.show()
		victory_screen.focus_default_button()

	var shot := 0

	for i in 200:
		await process_frame

		if i % 10 == 0:
			root.get_texture().get_image().save_png("%s/frame_%02d.png" % [out_dir, shot])
			shot += 1

	print("VICTORY CAPTURE DONE: %d frames" % shot)

	quit(0)
