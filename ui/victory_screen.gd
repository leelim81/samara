extends Control


signal continue_button_pressed

const ROWS_PATH := "MarginContainer/VBoxContainer/ResultsPanel/Margin/Rows"
const _MATERIAL_LIST_PATH := "res://items/material_list.tres"
const _COIN_ICON := preload("res://assets/terra/ui/coin.png")

const _BURST_TEX := preload("res://assets/vfx/victory_halo.png")
const _GLEAM_TEX := preload("res://assets/vfx/victory_gleam.png")
const _MOTE_TEX := preload("res://assets/vfx/glow_spark.png")

var _spoils: Dictionary = {}
var _turn_count: int = 0
var _drag_time_seconds: float = 0.0

var _title_burst: TextureRect
var _underline: TextureRect
var _motes: CPUParticles2D

var _breathe_tween: Tween
var _pulse_tween: Tween


func _ready() -> void:
	_build_entrance_effects()


# The Continue button is intentionally text-only (no icon): an arrow read as
# clutter on the results screen.
func _build_entrance_effects() -> void:
	# Slow, warm light motes drift upward behind everything so the screen feels
	# alive and lit rather than a static card (Final Fantasy results feel).
	_motes = CPUParticles2D.new()
	_motes.texture = _MOTE_TEX
	_motes.amount = 16
	_motes.lifetime = 7.0
	_motes.preprocess = 3.5
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.direction = Vector2(0, -1)
	_motes.spread = 16.0
	_motes.gravity = Vector2(0, -18)
	_motes.initial_velocity_min = 16.0
	_motes.initial_velocity_max = 42.0
	_motes.scale_amount_min = 0.10
	_motes.scale_amount_max = 0.28
	_motes.color_ramp = _mote_ramp()
	_motes.material = _additive_material()
	add_child(_motes)
	move_child(_motes, 1)

	# Warm bloom behind the VICTORY title: above the backdrop, behind the text.
	_title_burst = TextureRect.new()
	_title_burst.texture = _BURST_TEX
	_title_burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_burst.material = _additive_material()
	_title_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_burst.modulate.a = 0.0
	add_child(_title_burst)
	move_child(_title_burst, 2)

	# An elegant light rule that draws outward from the center beneath the title,
	# replacing the old left-to-right sweep. Repurposes the soft gleam streak so
	# it reads as a symmetric glow, not a moving flash.
	_underline = TextureRect.new()
	_underline.texture = _GLEAM_TEX
	_underline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_underline.stretch_mode = TextureRect.STRETCH_SCALE
	_underline.material = _additive_material()
	_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underline.modulate.a = 0.0
	add_child(_underline)


func _mote_ramp() -> Gradient:
	# Motes fade in and back out over their life so none pop on or off.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	g.colors = PackedColorArray([
		Color(0.95, 0.82, 0.5, 0.0),
		Color(0.95, 0.82, 0.5, 0.24),
		Color(0.95, 0.82, 0.5, 0.24),
		Color(0.95, 0.82, 0.5, 0.0),
	])
	return g


func _additive_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func focus_default_button() -> void:
	$MarginContainer/VBoxContainer/ContinueButton.grab_focus()


func initialize(total_drag_time_seconds: float, player_turn_count: int, spoils: Dictionary = {}, squad_gains: Array = [], drops: Dictionary = {}) -> void:
	_drag_time_seconds = total_drag_time_seconds
	_turn_count = player_turn_count
	_spoils = spoils

	_build_squad_gain_rows(squad_gains)
	_build_material_rows(_spoils.get("materials", {}))
	_build_luck_rows(drops)

	# Static lines fill in immediately; the spoils count up on reveal
	_set_value("TurnRow", str(player_turn_count))
	_set_value("TimeRow", "%0.1f s" % total_drag_time_seconds)
	_set_value("ExpRow", "0")
	_set_value("CoinRow", "0")
	_set_value("DefeatedRow", "0")


# One compact line per hero under the spoils: "Name  +120 EXP", with a gold
# "LEVEL UP!" when this battle's share pushes them over a threshold.
func _build_squad_gain_rows(squad_gains: Array) -> void:
	var rows: VBoxContainer = get_node(ROWS_PATH)
	var holder: VBoxContainer = rows.get_node_or_null("SquadGains")

	if holder != null:
		holder.queue_free()

	if squad_gains.is_empty():
		return

	holder = VBoxContainer.new()
	holder.name = "SquadGains"
	holder.add_theme_constant_override("separation", 6)
	rows.add_child(holder)

	var top_rule := HSeparator.new()
	holder.add_child(top_rule)

	for gain in squad_gains:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		holder.add_child(hb)

		var name_label := Label.new()
		name_label.text = gain.name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0.863, 0.878, 0.894, 0.85))
		hb.add_child(name_label)

		if gain.levels_gained > 0:
			var up := Label.new()
			up.text = tr("LEVEL_UP") if gain.levels_gained == 1 else tr("LEVEL_UP_MULTI") % gain.levels_gained
			up.add_theme_font_size_override("font_size", 16)
			up.add_theme_color_override("font_color", Color(0.95, 0.82, 0.5, 1))
			hb.add_child(up)

		var exp_label := Label.new()
		exp_label.text = tr("EXP_GAIN_FORMAT") % gain.gain
		exp_label.add_theme_font_size_override("font_size", 18)
		exp_label.add_theme_color_override("font_color", Color(0.42, 0.9, 0.72, 1))
		hb.add_child(exp_label)


# Dropped materials as icon + name + "x N" rows, hidden until revealed after the
# spoils count up (see _reveal_materials).
func _build_material_rows(materials: Dictionary) -> void:
	var rows: VBoxContainer = get_node(ROWS_PATH)
	var holder: VBoxContainer = rows.get_node_or_null("MaterialDrops")

	if holder != null:
		holder.queue_free()

	if materials.is_empty():
		return

	var registry = load(_MATERIAL_LIST_PATH)

	holder = VBoxContainer.new()
	holder.name = "MaterialDrops"
	holder.add_theme_constant_override("separation", 6)
	holder.modulate.a = 0.0
	rows.add_child(holder)

	holder.add_child(HSeparator.new())

	var header := Label.new()
	header.text = tr("MATERIALS")
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.6, 0.64, 0.667))
	holder.add_child(header)

	for item_id in materials:
		var item: Item = registry.get_by_id(item_id) if registry != null else null

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		holder.add_child(hb)

		if item != null and item.icon != null:
			var icon := TextureRect.new()
			icon.texture = item.icon
			icon.custom_minimum_size = Vector2(26, 26)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hb.add_child(icon)

		var name_label := Label.new()
		name_label.text = tr(item.name_key) if item != null else item_id
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0.863, 0.878, 0.894, 0.85))
		hb.add_child(name_label)

		var count_label := Label.new()
		count_label.text = "x%d" % int(materials[item_id])
		count_label.add_theme_font_size_override("font_size", 18)
		count_label.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42, 1))
		hb.add_child(count_label)


func _reveal_materials() -> void:
	var holder = get_node(ROWS_PATH).get_node_or_null("MaterialDrops")

	if holder == null:
		return

	var tween := create_tween()
	tween.tween_property(holder, "modulate:a", 1.0, 0.3)


# The squad's luck drops: bonus coins and any bonus materials, revealed last.
func _build_luck_rows(drops: Dictionary) -> void:
	var rows: VBoxContainer = get_node(ROWS_PATH)
	var holder: VBoxContainer = rows.get_node_or_null("LuckDrops")

	if holder != null:
		holder.queue_free()

	var coins: int = int(drops.get("coins", 0))
	var materials: Dictionary = drops.get("materials", {})

	if coins <= 0 and materials.is_empty():
		return

	var registry = load(_MATERIAL_LIST_PATH)

	holder = VBoxContainer.new()
	holder.name = "LuckDrops"
	holder.add_theme_constant_override("separation", 6)
	holder.modulate.a = 0.0
	rows.add_child(holder)

	holder.add_child(HSeparator.new())

	var header := Label.new()
	header.text = tr("LUCK_BONUS")
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42))
	holder.add_child(header)

	if coins > 0:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		holder.add_child(hb)

		var icon := TextureRect.new()
		icon.texture = _COIN_ICON
		icon.custom_minimum_size = Vector2(24, 24)
		icon.modulate = Color(0.86, 0.72, 0.42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(icon)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(spacer)

		var coin_label := Label.new()
		coin_label.text = "+%d" % coins
		coin_label.add_theme_font_size_override("font_size", 18)
		coin_label.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42, 1))
		hb.add_child(coin_label)

	for item_id in materials:
		var item: Item = registry.get_by_id(item_id) if registry != null else null

		var mrow := HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 10)
		holder.add_child(mrow)

		if item != null and item.icon != null:
			var micon := TextureRect.new()
			micon.texture = item.icon
			micon.custom_minimum_size = Vector2(24, 24)
			micon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			micon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mrow.add_child(micon)

		var name_label := Label.new()
		name_label.text = tr(item.name_key) if item != null else item_id
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0.863, 0.878, 0.894, 0.85))
		mrow.add_child(name_label)

		var count_label := Label.new()
		count_label.text = "x%d" % int(materials[item_id])
		count_label.add_theme_font_size_override("font_size", 18)
		count_label.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42, 1))
		mrow.add_child(count_label)


func _reveal_luck() -> void:
	var holder = get_node(ROWS_PATH).get_node_or_null("LuckDrops")

	if holder == null:
		return

	var tween := create_tween()
	tween.tween_property(holder, "modulate:a", 1.0, 0.3)


func _set_value(row_name: String, text: String) -> void:
	get_node("%s/%s/Value" % [ROWS_PATH, row_name]).text = text


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_inside_tree():
		_play_entrance()


# Final Fantasy-style reveal: warm light swells behind the title, VICTORY
# settles in softly and a light rule draws outward beneath it, the results
# panel rises, then each spoil line arrives and counts up in sequence.
func _play_entrance() -> void:
	var title: Label = $MarginContainer/VBoxContainer/Label
	var results: Control = $MarginContainer/VBoxContainer/ResultsPanel
	var button: Control = $MarginContainer/VBoxContainer/ContinueButton

	# Replaying (screen re-shown): stop any looping glow/pulse from last time so
	# they never stack.
	if is_instance_valid(_breathe_tween):
		_breathe_tween.kill()
	if is_instance_valid(_pulse_tween):
		_pulse_tween.kill()

	# Wait one frame so container layout (title/results rects) is valid.
	await get_tree().process_frame

	var vp: Vector2 = get_viewport_rect().size

	# Drift the motes up across the full width, rising from just below the frame.
	_motes.position = Vector2(vp.x / 2.0, vp.y + 16.0)
	_motes.emission_rect_extents = Vector2(vp.x / 2.0, 8.0)

	$ColorRect.modulate.a = 0.0
	create_tween().tween_property($ColorRect, "modulate:a", 1.0, 0.35)

	# Position the warm bloom over the title center.
	var title_center: Vector2 = title.global_position + title.size / 2.0
	var burst_size := Vector2(520, 520)
	_title_burst.size = burst_size
	_title_burst.pivot_offset = burst_size / 2.0
	_title_burst.position = title_center - burst_size / 2.0
	_title_burst.scale = Vector2(0.5, 0.5)

	# Bloom swells outward, settles to a soft ambient level, then breathes.
	var bloom := create_tween()
	bloom.tween_property(_title_burst, "modulate:a", 0.9, 0.32).set_ease(Tween.EASE_OUT)
	bloom.parallel().tween_property(_title_burst, "scale", Vector2(1.2, 1.2), 0.6) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bloom.chain().tween_property(_title_burst, "modulate:a", 0.4, 0.6)
	bloom.chain().tween_callback(_breathe_bloom)

	# VICTORY eases in with a soft scale settle (no hard punch).
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2(1.14, 1.14)
	title.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(title, "modulate:a", 1.0, 0.28)
	t.parallel().tween_property(title, "scale", Vector2.ONE, 0.6) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# The light rule draws outward from center beneath the title.
	_draw_underline(title)

	# Spoils lines start hidden so each can arrive right before it counts.
	var rows := get_node(ROWS_PATH)
	for row_name in ["ExpRow", "CoinRow", "DefeatedRow"]:
		rows.get_node(row_name).modulate.a = 0.0

	results.pivot_offset = Vector2(results.size.x / 2.0, 0)
	results.scale = Vector2(1.0, 0.94)
	results.modulate.a = 0.0
	button.modulate.a = 0.0

	await get_tree().create_timer(0.5).timeout

	# Results panel rises (a subtle vertical grow reads as a lift).
	var rise := create_tween()
	rise.tween_property(results, "modulate:a", 1.0, 0.32)
	rise.parallel().tween_property(results, "scale", Vector2.ONE, 0.42) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await rise.finished

	# Each spoil line fades in, then counts up, one after another.
	await _reveal_and_count("ExpRow", int(_spoils.get("exp", 0)))
	await _reveal_and_count("CoinRow", int(_spoils.get("coins", 0)))
	await _reveal_and_count("DefeatedRow", int(_spoils.get("defeated", 0)))

	# The Continue button fades in and breathes gently to invite the tap.
	create_tween().tween_property(button, "modulate:a", 1.0, 0.3)
	_pulse_button(button)

	await get_tree().create_timer(0.18).timeout

	_reveal_materials()

	await get_tree().create_timer(0.18).timeout

	_reveal_luck()


# Draws a soft light rule outward from the center, just under the title text.
func _draw_underline(title: Control) -> void:
	var w := 340.0
	var h := 22.0
	var title_center: Vector2 = title.global_position + title.size / 2.0
	var underline_y: float = title.global_position.y + title.size.y * 0.72

	_underline.size = Vector2(w, h)
	_underline.pivot_offset = Vector2(w / 2.0, h / 2.0)
	_underline.position = Vector2(title_center.x - w / 2.0, underline_y - h / 2.0)
	_underline.scale = Vector2(0.02, 1.0)
	_underline.modulate.a = 0.0

	var draw := create_tween()
	draw.tween_interval(0.24)
	draw.tween_property(_underline, "scale:x", 1.0, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	draw.parallel().tween_property(_underline, "modulate:a", 0.85, 0.3)
	draw.chain().tween_property(_underline, "modulate:a", 0.5, 0.55)


# The bloom behind the title breathes slowly, keeping the screen alive.
func _breathe_bloom() -> void:
	if not is_instance_valid(_title_burst):
		return

	_breathe_tween = create_tween().set_loops()
	_breathe_tween.tween_property(_title_burst, "modulate:a", 0.5, 1.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.parallel().tween_property(_title_burst, "scale", Vector2(1.28, 1.28), 1.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.tween_property(_title_burst, "modulate:a", 0.32, 1.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe_tween.parallel().tween_property(_title_burst, "scale", Vector2(1.2, 1.2), 1.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# The Continue button breathes to draw the eye once results are in.
func _pulse_button(button: Control) -> void:
	button.pivot_offset = button.size / 2.0

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(button, "scale", Vector2(1.03, 1.03), 0.95) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(button, "scale", Vector2.ONE, 0.95) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Fades one spoil line in, counts it up, and holds a beat before the next.
func _reveal_and_count(row_name: String, target: int) -> void:
	var row: Control = get_node("%s/%s" % [ROWS_PATH, row_name])

	var fade := create_tween()
	fade.tween_property(row, "modulate:a", 1.0, 0.2)
	await fade.finished

	_count_up(row_name, target, "")

	await get_tree().create_timer(0.34).timeout


# Animates a result value from 0 to its total with a tick sound and a
# small pop as it lands
func _count_up(row_name: String, target: int, suffix: String) -> void:
	if target <= 0:
		_set_value(row_name, "0" + suffix)
		return

	var value_label: Label = get_node("%s/%s/Value" % [ROWS_PATH, row_name])
	var duration: float = clampf(target / 600.0, 0.35, 0.9)

	var count_tween := create_tween()
	count_tween.tween_method(
		func(v: float): value_label.text = str(int(v)) + suffix,
		0.0, float(target), duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	count_tween.tween_callback(func(): _pop_label(value_label))

	$CountAudio.play()


func _pop_label(label: Label) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.25, 1.25)

	var pop := create_tween()
	pop.tween_property(label, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _on_ContinueButton_pressed() -> void:
	emit_signal("continue_button_pressed")
