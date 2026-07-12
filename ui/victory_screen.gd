extends Control


signal continue_button_pressed

const ROWS_PATH := "MarginContainer/VBoxContainer/ResultsPanel/Margin/Rows"
const _MATERIAL_LIST_PATH := "res://items/material_list.tres"
const _COIN_ICON := preload("res://assets/terra/ui/coin.png")

const _BURST_TEX := preload("res://assets/vfx/victory_burst.png")
const _GLEAM_TEX := preload("res://assets/vfx/victory_gleam.png")

var _spoils: Dictionary = {}
var _turn_count: int = 0
var _drag_time_seconds: float = 0.0

var _title_burst: TextureRect
var _gleam: TextureRect
var _flash: ColorRect


func _ready() -> void:
	_build_entrance_effects()


# The Continue button is intentionally text-only (no icon): an arrow read as
# clutter on the results screen.
func _build_entrance_effects() -> void:
	# Warm light bloom behind the VICTORY title (drawn above the backdrop but
	# behind the text).
	_title_burst = TextureRect.new()
	_title_burst.texture = _BURST_TEX
	_title_burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_burst.material = _additive_material()
	_title_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_burst.modulate.a = 0.0
	add_child(_title_burst)
	move_child(_title_burst, 1)

	# A light streak that sweeps across the title once, on top of the text.
	_gleam = TextureRect.new()
	_gleam.texture = _GLEAM_TEX
	_gleam.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gleam.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gleam.material = _additive_material()
	_gleam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gleam.modulate.a = 0.0
	add_child(_gleam)

	# A brief white impact flash over everything.
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 1)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)


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


# Final Fantasy-style reveal: a light burst behind the title, the word VICTORY
# punches in with an impact flash and a gleam sweep, the results panel rises,
# then the spoils count up in sequence.
func _play_entrance() -> void:
	var title: Label = $MarginContainer/VBoxContainer/Label
	var results: Control = $MarginContainer/VBoxContainer/ResultsPanel
	var button: Control = $MarginContainer/VBoxContainer/ContinueButton

	# Wait one frame so container layout (title/results rects) is valid.
	await get_tree().process_frame

	$ColorRect.modulate.a = 0.0
	create_tween().tween_property($ColorRect, "modulate:a", 1.0, 0.3)

	# Position the light bloom over the title center.
	var title_center: Vector2 = title.global_position + title.size / 2.0
	var burst_size := Vector2(480, 480)
	_title_burst.size = burst_size
	_title_burst.pivot_offset = burst_size / 2.0
	_title_burst.position = title_center - burst_size / 2.0
	_title_burst.scale = Vector2(0.4, 0.4)

	# Impact flash: a quick white pop as the title lands.
	_flash.modulate.a = 0.0
	var flash := create_tween()
	flash.tween_interval(0.08)
	flash.tween_property(_flash, "modulate:a", 0.55, 0.05)
	flash.tween_property(_flash, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)

	# Light bloom: blooms outward, then settles to a soft ambient glow.
	var bloom := create_tween()
	bloom.set_parallel(true)
	bloom.tween_property(_title_burst, "modulate:a", 0.95, 0.28).set_ease(Tween.EASE_OUT)
	bloom.tween_property(_title_burst, "scale", Vector2(1.1, 1.1), 0.55) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bloom.chain().tween_property(_title_burst, "modulate:a", 0.4, 0.6)

	# VICTORY punches in.
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2(1.22, 1.22)
	title.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(title, "modulate:a", 1.0, 0.22)
	t.tween_property(title, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# A gleam sweeps across the title as it lands.
	_sweep_gleam(title)

	# Results panel rises and fades in, then the button.
	results.pivot_offset = Vector2(results.size.x / 2.0, 0)
	results.scale = Vector2(1.0, 0.92)
	results.modulate.a = 0.0
	button.modulate.a = 0.0

	await get_tree().create_timer(0.22).timeout

	var rise := create_tween()
	rise.set_parallel(true)
	rise.tween_property(results, "modulate:a", 1.0, 0.3)
	rise.tween_property(results, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await rise.finished

	_count_up("ExpRow", int(_spoils.get("exp", 0)), "")
	await get_tree().create_timer(0.18).timeout

	_count_up("CoinRow", int(_spoils.get("coins", 0)), "")
	await get_tree().create_timer(0.18).timeout

	_count_up("DefeatedRow", int(_spoils.get("defeated", 0)), "")

	create_tween().tween_property(button, "modulate:a", 1.0, 0.3)

	await get_tree().create_timer(0.18).timeout

	_reveal_materials()

	await get_tree().create_timer(0.18).timeout

	_reveal_luck()


# A soft light streak travels left to right across the title once.
func _sweep_gleam(title: Control) -> void:
	var h: float = title.size.y
	_gleam.size = Vector2(120, h)
	var start_x: float = title.global_position.x - 90.0
	var end_x: float = title.global_position.x + title.size.x + 90.0
	_gleam.position = Vector2(start_x, title.global_position.y)
	_gleam.modulate.a = 0.0

	var move := create_tween()
	move.tween_interval(0.14)
	move.tween_property(_gleam, "position:x", end_x, 0.55).set_trans(Tween.TRANS_SINE)

	var fade := create_tween()
	fade.tween_interval(0.14)
	fade.tween_property(_gleam, "modulate:a", 0.85, 0.14)
	fade.tween_interval(0.2)
	fade.tween_property(_gleam, "modulate:a", 0.0, 0.2)


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
