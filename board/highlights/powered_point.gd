extends Node2D
# Terra Battle "Powered Point": a glowing teal disc with a "P" on a board tile.
# A unit standing on this cell gets 100% skill activation (see unit.activate_skills
# and board._spawn_powered_point). Built programmatically (no new art) so it pulses
# and can play a consume pop. Parent it under Board/PoweredPoints (Board-local coords).

var _pulse: Tween
var _spin: Tween

# Rotating ring holder (TB's point spins in place while pulsing)
var _spinner: Node2D


func _ready() -> void:
	_build()
	_play_spawn()


# TB-style arrival: the point blooms in with a flash ring, then settles
# into its idle breathing.
func _play_spawn() -> void:
	scale = Vector2(2.4, 2.4)
	modulate = Color(2.4, 2.4, 2.4, 0.0)

	_flash_ring(0.4, 1.9, 0.5)
	_flash_ring(0.2, 1.2, 0.35, Color(0.95, 1.0, 0.98, 0.9))

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2.4, 2.4, 2.4, 1.0), 0.14)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	tween.tween_callback(_start_pulse)


# One-shot expanding halo used by the spawn bloom and the consume burst.
func _flash_ring(from_scale: float, to_scale: float, duration: float, color: Color = Color(0.62, 0.97, 0.92, 0.85)) -> void:
	var ring := Sprite2D.new()
	ring.texture = load("res://assets/ui/cell_highlight.png")
	ring.modulate = color
	ring.scale = Vector2(from_scale, from_scale)

	# Parent to the board layer when possible so the burst outlives this
	# disc's queue_free during the consume pop.
	var host: Node = get_parent() if get_parent() != null else self
	host.add_child(ring)

	if host != self:
		ring.position = position

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(to_scale, to_scale), duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)


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

	# Notched orbit ring: satellite ticks that make the rotation readable
	# (a plain circle spinning shows nothing).
	_spinner = Node2D.new()
	add_child(_spinner)

	for i in 4:
		var angle: float = TAU * float(i) / 4.0
		var tick := Polygon2D.new()
		tick.polygon = PackedVector2Array([
			Vector2(-6, -2.6), Vector2(6, -2.6), Vector2(6, 2.6), Vector2(-6, 2.6)
		])
		tick.color = Color(0.72, 0.99, 0.96, 0.95)
		tick.position = Vector2(cos(angle), sin(angle)) * 33.0
		tick.rotation = angle + PI / 2.0
		_spinner.add_child(tick)

		var dot := Polygon2D.new()
		dot.polygon = _circle_points(2.4, 10)
		dot.color = Color(0.55, 0.95, 0.98, 0.75)
		var mid: float = angle + TAU / 8.0
		dot.position = Vector2(cos(mid), sin(mid)) * 33.0
		_spinner.add_child(dot)

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
	# TB reference: the point stays on its cell, spinning steadily while the
	# whole orb breathes in scale.
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "scale", Vector2(1.12, 1.12), 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(self, "scale", Vector2(0.9, 0.9), 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_spin = create_tween().set_loops()
	_spin.tween_property(_spinner, "rotation", TAU, 3.2) \
			.from(0.0).set_trans(Tween.TRANS_LINEAR)


func place(cell) -> void:
	position = cell.position


func consume() -> void:
	if is_instance_valid(_pulse):
		_pulse.kill()

	if is_instance_valid(_spin):
		_spin.kill()

	# Chaining the point arms the turn-wide x1.5 boost, so the payoff is
	# bigger than the old pop: white-hot flash, double burst ring, and a
	# rising "POWER x1.5" tag left behind at the cell.
	_flash_ring(0.8, 2.4, 0.5, Color(0.95, 1.0, 0.98, 0.9))
	_spawn_boost_tag()

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.08)
	tween.tween_property(self, "scale", Vector2(1.7, 1.7), 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 0.0), 0.2)
	tween.tween_callback(queue_free)


# Rising, fading "POWER x1.5" text at the consumed cell (parented to the
# board layer so it outlives this node).
func _spawn_boost_tag() -> void:
	if get_parent() == null:
		return

	var tag := Label.new()
	tag.text = "POWER x1.5"
	tag.z_index = 10
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Color(0.62, 0.97, 0.88, 1))
	tag.add_theme_color_override("font_outline_color", Color(0.03, 0.1, 0.1, 0.9))
	tag.add_theme_constant_override("outline_size", 6)
	tag.position = position + Vector2(-56, -46)
	get_parent().add_child(tag)

	var tween := tag.create_tween()
	tween.tween_property(tag, "position:y", tag.position.y - 40.0, 0.9) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(tag, "modulate:a", 0.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(tag.queue_free)
