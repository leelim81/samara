extends SceneTree
# Dev tool: renders the victory screen with materials + a luck bonus. The count-up
# and reveal use SceneTreeTimers that stall under --script, so this forces the
# final state before the screenshot.
#   godot --path . --script res://tools/shot_victory_drops.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var vs = load("res://ui/victory_screen.tscn").instantiate()
	root.add_child(vs)

	await process_frame

	var spoils = {"exp": 720, "coins": 340, "defeated": 6, "materials": {"scrap": 2, "alloy": 1}}
	var gains = [{"name": "Shi Jin (Nine Dragons)", "gain": 120, "levels_gained": 1}]
	var drops = {"coins": 180, "materials": {"cell": 1}, "chests": 3}

	vs.initialize(27.4, 5, spoils, gains, drops)

	# Let the entrance tweens settle.
	for i in 45:
		await process_frame

	var rows_path := "MarginContainer/VBoxContainer/ResultsPanel/Margin/Rows"
	vs.get_node(rows_path + "/ExpRow/Value").text = "720"
	vs.get_node(rows_path + "/CoinRow/Value").text = "340"
	vs.get_node(rows_path + "/DefeatedRow/Value").text = "6"

	for holder_name in ["SquadGains", "MaterialDrops", "LuckDrops"]:
		var holder = vs.get_node(rows_path).get_node_or_null(holder_name)
		if holder != null:
			holder.modulate.a = 1.0

	var panel = vs.get_node("MarginContainer/VBoxContainer")
	panel.modulate.a = 1.0
	panel.scale = Vector2.ONE
	vs.get_node("ColorRect").modulate.a = 1.0

	for i in 20:
		await process_frame

	root.get_texture().get_image().save_png("/tmp/victory_drops.png")
	print("SHOT SAVED")

	quit(0)
