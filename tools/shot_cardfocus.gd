extends SceneTree
# Dev tool: focuses the first chapter card and screenshots so the hover/
# focus highlight can be checked (single outline, no zoom).
#   godot --path . --script res://tools/shot_cardfocus.gd -- <out.png>


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "/tmp/cardfocus.png"

	var hub = (load("res://ui/pre_battle_menu/pre_battle_menu.tscn") as PackedScene).instantiate()
	root.add_child(hub)

	for i in 40:
		await process_frame

	var list = hub.get_node("MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer2")

	for child in list.get_children():
		var btn = child.get_node_or_null("CardButton")
		if btn != null:
			btn.grab_focus()
			break

	for i in 30:
		await process_frame

	root.get_texture().get_image().save_png(out_path)
	print("SHOT SAVED: %s" % out_path)

	quit(0)
