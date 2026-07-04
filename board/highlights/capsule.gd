extends Node2D
# Terra Battle capsule: a small glowing disc dropped on a tile by a defeated
# enemy. Chaining its cell collects it (capsule phase, after healing).
# RECOVERY = green "+" (heals the squad), COIN = gold "$" (bonus coins).
# Built programmatically like powered_point.gd (no new art). Parent under
# Board/Capsules (Board-local coords).

var _pulse: Tween


func initialize(capsule_type: int) -> void:
	var disc_color: Color
	var inner_color: Color
	var glyph: String
	var glyph_color: Color

	match capsule_type:
		Enums.CapsuleType.RECOVERY:
			disc_color = Color(0.22, 0.66, 0.36, 0.92)
			inner_color = Color(0.62, 0.94, 0.68, 0.9)
			glyph = "+"
			glyph_color = Color(0.05, 0.22, 0.09)
		_:
			disc_color = Color(0.82, 0.64, 0.16, 0.92)
			inner_color = Color(0.99, 0.88, 0.5, 0.9)
			glyph = "$"
			glyph_color = Color(0.26, 0.18, 0.02)

	# Glowing tile underlay (reuse the cell-highlight art).
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/ui/cell_highlight.png")
	glow.scale = Vector2(1.06, 1.06)
	glow.modulate = Color(disc_color.r, disc_color.g, disc_color.b, 0.4)
	add_child(glow)

	var disc := Polygon2D.new()
	disc.polygon = _circle_points(22.0, 24)
	disc.color = disc_color
	add_child(disc)

	var inner := Polygon2D.new()
	inner.polygon = _circle_points(16.0, 24)
	inner.color = inner_color
	add_child(inner)

	var label := Label.new()
	label.text = glyph
	label.custom_minimum_size = Vector2(40, 40)
	label.position = Vector2(-20, -22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", glyph_color)
	add_child(label)

	_start_pulse()


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()

	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		points.push_back(Vector2(cos(angle), sin(angle)) * radius)

	return points


func _start_pulse() -> void:
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "scale", Vector2(1.08, 1.08), 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(self, "scale", Vector2(0.94, 0.94), 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func consume() -> void:
	if is_instance_valid(_pulse):
		_pulse.kill()

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
