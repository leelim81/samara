extends Control


signal continue_button_pressed

const ROWS_PATH := "MarginContainer/VBoxContainer/ResultsPanel/Margin/Rows"
const _MATERIAL_LIST_PATH := "res://items/material_list.tres"

var _spoils: Dictionary = {}
var _turn_count: int = 0
var _drag_time_seconds: float = 0.0


func focus_default_button() -> void:
	$MarginContainer/VBoxContainer/ContinueButton.grab_focus()


func initialize(total_drag_time_seconds: float, player_turn_count: int, spoils: Dictionary = {}, squad_gains: Array = []) -> void:
	_drag_time_seconds = total_drag_time_seconds
	_turn_count = player_turn_count
	_spoils = spoils

	_build_squad_gain_rows(squad_gains)
	_build_material_rows(_spoils.get("materials", {}))

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
			up.text = "LEVEL UP!" if gain.levels_gained == 1 else "LEVEL UP x%d!" % gain.levels_gained
			up.add_theme_font_size_override("font_size", 16)
			up.add_theme_color_override("font_color", Color(0.95, 0.82, 0.5, 1))
			hb.add_child(up)

		var exp_label := Label.new()
		exp_label.text = "+%d EXP" % gain.gain
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


func _set_value(row_name: String, text: String) -> void:
	get_node("%s/%s/Value" % [ROWS_PATH, row_name]).text = text


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_inside_tree():
		_play_entrance()


# Dim in the backdrop, pop the panel, then count the spoils up in sequence
func _play_entrance() -> void:
	var panel: Control = $MarginContainer/VBoxContainer

	$ColorRect.modulate.a = 0.0

	var fade_tween := create_tween()
	fade_tween.tween_property($ColorRect, "modulate:a", 1.0, 0.35)

	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0

	var pop_tween := create_tween()
	pop_tween.set_parallel(true)
	pop_tween.tween_property(panel, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(panel, "modulate:a", 1.0, 0.3)

	await pop_tween.finished

	_count_up("ExpRow", int(_spoils.get("exp", 0)), "")
	await get_tree().create_timer(0.18).timeout

	_count_up("CoinRow", int(_spoils.get("coins", 0)), "")
	await get_tree().create_timer(0.18).timeout

	_count_up("DefeatedRow", int(_spoils.get("defeated", 0)), "")

	await get_tree().create_timer(0.18).timeout

	_reveal_materials()


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


func _on_VictoryScreen_visibility_changed() -> void:
	$CPUParticles2D.emitting = visible
