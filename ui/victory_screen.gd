extends Control


signal continue_button_pressed

const ROWS_PATH := "MarginContainer/VBoxContainer/ResultsPanel/Margin/Rows"

var _spoils: Dictionary = {}
var _turn_count: int = 0
var _drag_time_seconds: float = 0.0


func focus_default_button() -> void:
	$MarginContainer/VBoxContainer/ContinueButton.grab_focus()


func initialize(total_drag_time_seconds: float, player_turn_count: int, spoils: Dictionary = {}) -> void:
	_drag_time_seconds = total_drag_time_seconds
	_turn_count = player_turn_count
	_spoils = spoils

	# Static lines fill in immediately; the spoils count up on reveal
	_set_value("TurnRow", str(player_turn_count))
	_set_value("TimeRow", "%0.1f s" % total_drag_time_seconds)
	_set_value("ExpRow", "0")
	_set_value("CoinRow", "0")
	_set_value("DefeatedRow", "0")


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
