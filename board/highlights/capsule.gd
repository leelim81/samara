extends Node2D
# Terra Battle capsule: a small glowing disc dropped on a tile by a defeated
# enemy. Chaining its cell collects it (capsule phase, after healing).
# RECOVERY = green "+" (heals the squad), COIN = gold "$" (bonus coins).
# Built programmatically like powered_point.gd (no new art). Parent under
# Board/Capsules (Board-local coords).

var _pulse: Tween

# Inner disc color, reused by the spawn ring, collect burst and reward tag.
var _accent: Color = Color.WHITE


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

	_accent = inner_color

	_play_spawn()


# Loot drop: the capsule falls onto the tile with a little bounce and a
# soft ring in its own color, then starts its idle breathing.
func _play_spawn() -> void:
	var rest_y: float = position.y

	position.y = rest_y - 34.0
	scale = Vector2(1.35, 1.35)
	modulate.a = 0.0

	_flash_ring(0.35, 1.2, 0.4)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(self, "position:y", rest_y, 0.42) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.42) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_start_pulse)


# One-shot expanding halo in the capsule's own color.
func _flash_ring(from_scale: float, to_scale: float, duration: float) -> void:
	var ring := Sprite2D.new()
	ring.texture = load("res://assets/ui/cell_highlight.png")
	ring.modulate = Color(_accent.r, _accent.g, _accent.b, 0.85)
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


# Rising, fading reward tag at the collected cell (parented to the board
# layer so it outlives this disc).
func _spawn_reward_tag(text: String) -> void:
	if get_parent() == null or text.is_empty():
		return

	var tag := Label.new()
	tag.text = text
	tag.z_index = 10
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Color(_accent.r, _accent.g, _accent.b, 1))
	tag.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.05, 0.9))
	tag.add_theme_constant_override("outline_size", 6)
	tag.position = position + Vector2(-52, -46)
	get_parent().add_child(tag)

	var tween := tag.create_tween()
	tween.tween_property(tag, "position:y", tag.position.y - 40.0, 0.9) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(tag, "modulate:a", 0.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(tag.queue_free)


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


func consume(reward_tag: String = "") -> void:
	if is_instance_valid(_pulse):
		_pulse.kill()

	_flash_ring(0.7, 2.0, 0.45)
	_spawn_reward_tag(reward_tag)

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2.6, 2.6, 2.6, 1.0), 0.08)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color(2.6, 2.6, 2.6, 0.0), 0.2)
	tween.tween_callback(queue_free)
