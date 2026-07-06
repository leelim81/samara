extends SceneTree
# Verifies the row's mouse-filter wiring after the whole-cell-click change:
#   - Card is the single STOP hit target
#   - portrait + stat labels are IGNORE (so clicks reach the Card)
#   - CHANGE button stays STOP (its own hit area)
#   - a draggable row still yields drag data (squad reorder intact)
#   godot --path . --script res://tools/probe_rowstructure.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var game_data = root.get_node("/root/GameData")
	game_data.load_data()

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(720, 200)
	root.add_child(holder)

	var row = load("res://ui/pre_battle_menu/unit_item_container.tscn").instantiate()
	holder.add_child(row)
	row.initialize(game_data.save_data.jobs[0], true, null) # draggable

	for i in 10:
		await process_frame

	var card: Control = row.get_node("Card")
	var icon: Control = row.get_node("Card/H/UnitIcon")
	var name_label: Control = row.get_node("Card/H/Body/NameRow/NameLabel")
	var a_stat: Control = row.get_node("Card/H/Body/UnitStatsContainer/HBoxContainer3/HealthNumber")
	var change_button: Control = row.get_node("Card/H/ChangeButton")

	var ok := true
	ok = _check("Card == STOP", card.mouse_filter == Control.MOUSE_FILTER_STOP) and ok
	ok = _check("UnitIcon == IGNORE", icon.mouse_filter == Control.MOUSE_FILTER_IGNORE) and ok
	ok = _check("NameLabel == IGNORE", name_label.mouse_filter == Control.MOUSE_FILTER_IGNORE) and ok
	ok = _check("HealthNumber == IGNORE", a_stat.mouse_filter == Control.MOUSE_FILTER_IGNORE) and ok
	ok = _check("ChangeButton == STOP", change_button.mouse_filter == Control.MOUSE_FILTER_STOP) and ok

	var drag_data = row._get_drag_data(Vector2.ZERO)
	ok = _check("draggable row yields drag data", drag_data == row) and ok

	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _check(label: String, cond: bool) -> bool:
	print("  [%s] %s" % ["ok" if cond else "XX", label])
	return cond
