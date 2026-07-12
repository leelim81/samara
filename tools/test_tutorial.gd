extends SceneTree
# Tests the guided first-battle tutorial overlay: steps advance on the real
# battle signals (drag, pincer cut-in, chain, timer). Never completes the
# final step, so the guide never writes the save file.
#   godot --headless --script res://tools/test_tutorial.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	var board = battle.get_node("Board")

	var reached := false
	for i in 1200:
		await process_frame
		if board._current_turn == board.Turn.PLAYER:
			reached = true
			break
	if not reached:
		printerr("FAIL: player turn never started")
		quit(1)
		return

	# Drive the guide directly (battle._ready loads the real save, whose
	# tutorial flag may be set; the guide's own mechanics are what we test).
	# Load the script at RUNTIME rather than via the TutorialGuide class_name:
	# a compile-time class reference would force tutorial_guide.gd to compile
	# in this --script tool's early load phase, before the GameData autoload
	# registers, which poisons the script and hangs the coroutine.
	var guide = load("res://ui/tutorial_guide.gd").new()
	guide.setup(board, battle)
	battle.add_child(guide)

	await process_frame
	await process_frame

	_check("step 1 shows the move callout", guide._text_label.text == tr("TUT_MOVE"))
	_check("ring targets a unit", guide._target.is_valid())

	# The player picks up a unit: the drag timer starts.
	board.emit_signal("drag_timer_started", null)
	await process_frame
	_check("drag advances to the pincer step", guide._text_label.text == tr("TUT_PINCER"))

	# A pincer resolves: the cut-in banner fires.
	root.get_node("/root/Events").emit_signal("cutin_requested", [], "", true, Color.WHITE, false)
	await process_frame
	_check("pincer advances to the chain step", guide._text_label.text == tr("TUT_CHAIN"))

	root.get_node("/root/Events").emit_signal("cutin_requested", [], "", true, Color.WHITE, false)
	await process_frame
	_check("next pincer advances to the timer step", guide._text_label.text == tr("TUT_TIMER"))

	board.emit_signal("drag_timer_stopped")
	await process_frame
	_check("drag end advances to the ready step", guide._text_label.text == tr("TUT_READY"))
	_check("final step drops the continue hint", guide._hint_label.text == "")

	# Quit before the final step's 2.6s auto-finish so the guide never saves.
	print("test_tutorial: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1
	print(("  PASS " if cond else "  FAIL ") + label)
