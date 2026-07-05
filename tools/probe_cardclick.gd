extends SceneTree
# Probe: click the bottom-right corner of the first chapter card (far from
# the title) and confirm the whole cell is a tap target.
#   godot --script res://tools/probe_cardclick.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hub = (load("res://ui/pre_battle_menu/pre_battle_menu.tscn") as PackedScene).instantiate()
	root.add_child(hub)

	for i in 30:
		await process_frame

	var list = hub.get_node("MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer2")
	var card = null

	for child in list.get_children():
		if child.has_signal("pressed"):
			card = child
			break

	if card == null:
		print("PROBE: no card found")
		quit(1)
		return

	var fired := [false]
	card.pressed.connect(func(): fired[0] = true)

	# Bottom-right of the card: the Battles count corner
	var rect: Rect2 = card.get_global_rect()
	var point: Vector2 = rect.position + rect.size - Vector2(30, 14)

	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = point
		ev.global_position = point
		Input.parse_input_event(ev)
		await process_frame
		await process_frame

	print("PROBE: corner click fired the card = %s" % fired[0])

	quit(0 if fired[0] else 1)
