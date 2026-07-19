extends SceneTree
# Headless smoke test for the debug Gallery. Instantiates the list and detail
# screens and asserts they build correctly (list is populated with every unit;
# a hero's detail resolves all of its art forms with real textures).
#   godot --headless --script res://tools/test_gallery.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true

	# --- Global.DEBUG autoload ---
	var g = root.get_node_or_null("/root/Global")
	if g == null:
		print("  ! Global autoload not present in --script run (expected; validated via game run)")
	else:
		print("  Global.DEBUG = %s" % g.DEBUG)

	# --- Gallery list builds a row per unit ---
	var menu = load("res://ui/gallery_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame

	var list = menu.get_node("MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer")
	var buttons := 0
	var buttons_with_icon := 0
	var headers := 0
	for c in list.get_children():
		if c is Button:
			buttons += 1
			if c.icon != null:
				buttons_with_icon += 1
		elif c is Label:
			headers += 1

	print("  gallery list: %d section headers, %d unit buttons (%d with token icon)" % [headers, buttons, buttons_with_icon])
	if headers < 2 or buttons < 150 or buttons_with_icon < 100:
		push_error("gallery list did not populate as expected")
		ok = false
	menu.queue_free()

	# --- Detail page resolves a hero's forms + art (amazora: base/job2/job3/awakened) ---
	var detail = load("res://ui/gallery_detail_menu.tscn").instantiate()
	root.add_child(detail)
	await process_frame

	var job = load("res://jobs/terra/amazora_job.tres").duplicate()
	job.source_path = "res://jobs/terra/amazora_job.tres"
	detail.on_add_to_tree(job)
	await process_frame

	var content = detail.get_node("MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer")
	var sections: int = content.get_child_count()

	# Count how many TextureRects across the detail actually carry a texture.
	var textured: int = _count_textures(content)

	print("  amazora detail: %d form sections, %d art textures shown" % [sections, textured])
	if sections < 3 or textured < 4:
		push_error("amazora detail did not resolve its art forms")
		ok = false
	detail.queue_free()

	print("GALLERY TEST %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _count_textures(node: Node) -> int:
	var n := 0
	if node is TextureRect and node.texture != null:
		n += 1
	for child in node.get_children():
		n += _count_textures(child)
	return n
