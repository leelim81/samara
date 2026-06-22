extends Node2D
# Terra Battle "Powered Point": a glowing teal disc with a "P" on a board tile.
# A unit standing on this cell gets 100% skill activation (see unit.activate_skills
# and board._spawn_powered_point). Built programmatically (no new art) so it pulses
# and can play a consume pop. Parent it under Board/PoweredPoints (Board-local coords).

var _pulse: Tween


func _ready() -> void:
	_build()
	_start_pulse()


func _build() -> void:
	# Glowing tile underlay (reuse the cell-highlight art, tinted teal).
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/ui/cell_highlight.png")
	glow.scale = Vector2(1.06, 1.06)
	glow.modulate = Color(0.78, 0.97, 0.95, 0.45)
	add_child(glow)

	# Teal disc with a lighter inner fill for depth.
	var disc := Polygon2D.new()
	disc.polygon = _circle_points(26.0, 24)
	disc.color = Color(0.18, 0.74, 0.82, 0.92)
	add_child(disc)

	var inner := Polygon2D.new()
	inner.polygon = _circle_points(20.0, 24)
	inner.color = Color(0.55, 0.95, 0.98, 0.9)
	add_child(inner)

	# The "P".
	var label := Label.new()
	label.text = "P"
	label.custom_minimum_size = Vector2(40, 40)
	label.position = Vector2(-20, -23)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.04, 0.18, 0.21))
	add_child(label)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()

	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		points.push_back(Vector2(cos(angle), sin(angle)) * radius)

	return points


func _start_pulse() -> void:
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "scale", Vector2(1.1, 1.1), 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(self, "scale", Vector2(0.92, 0.92), 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func place(cell) -> void:
	position = cell.position


func consume() -> void:
	if is_instance_valid(_pulse):
		_pulse.kill()

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
