extends SceneTree
# Verifies the drag-mode control is a working TOGGLE (not a dropdown): flipping
# it emits drag_mode_changed with the opposite mode and swaps the glyph.
#   godot --path . --script res://tools/probe_dragtoggle.gd


var _last_mode := -1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var game_data = root.get_node("/root/GameData")
	game_data.load_data()
	game_data.save_data.drag_mode = Enums.DragMode.CLICK

	var button = load("res://ui/drag_mode_option_button.tscn").instantiate()
	root.add_child(button)
	button.connect("drag_mode_changed", Callable(self, "_on_mode"))

	for i in 5:
		await process_frame

	var ok := true
	ok = _check("starts un-pressed (CLICK)", not button.button_pressed) and ok
	var click_icon = button.icon

	# Flip to HOLD
	button.button_pressed = true
	await process_frame
	ok = _check("toggle -> emits HOLD", _last_mode == Enums.DragMode.HOLD) and ok
	ok = _check("icon changed on HOLD", button.icon != click_icon) and ok

	# Flip back to CLICK
	button.button_pressed = false
	await process_frame
	ok = _check("toggle -> emits CLICK", _last_mode == Enums.DragMode.CLICK) and ok
	ok = _check("icon restored on CLICK", button.icon == click_icon) and ok

	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _check(label: String, cond: bool) -> bool:
	print("  [%s] %s" % ["ok" if cond else "XX", label])
	return cond


func _on_mode(mode: int) -> void:
	_last_mode = mode
