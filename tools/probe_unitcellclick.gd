extends SceneTree
# Proves the WHOLE unit row is a click target (not just the portrait): builds a
# non-draggable row, synthesizes a left click over the stats area (far from the
# portrait), and asserts unit_selected fires.
#   godot --path . --script res://tools/probe_unitcellclick.gd


var _fired := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var game_data = root.get_node("/root/GameData")
	game_data.load_data()

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.custom_minimum_size = Vector2(720, 200)
	root.add_child(holder)

	var row = load("res://ui/pre_battle_menu/unit_item_container.tscn").instantiate()
	holder.add_child(row)
	row.initialize(game_data.save_data.jobs[0], false, null)
	row.hide_change_button()
	row.connect("unit_selected", Callable(self, "_on_selected"))

	for i in 20:
		await process_frame

	var card: Control = row.get_node("Card")
	var rect := card.get_global_rect()

	# A point well to the RIGHT of the portrait (over the stat numbers).
	var click_at := Vector2(rect.position.x + rect.size.x * 0.7, rect.position.y + rect.size.y * 0.5)

	_send_click(click_at)

	for i in 10:
		await process_frame

	print("CARD RECT: %s  CLICK: %s" % [rect, click_at])
	print("UNIT_SELECTED FIRED: %s" % _fired)
	print("RESULT: %s" % ("PASS" if _fired else "FAIL"))
	quit(0 if _fired else 1)


func _send_click(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	root.get_viewport().push_input(down)

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	root.get_viewport().push_input(up)


func _on_selected() -> void:
	_fired = true
