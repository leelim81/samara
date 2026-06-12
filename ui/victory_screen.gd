extends Control


signal continue_button_pressed


func focus_default_button() -> void:
	$MarginContainer/VBoxContainer/ContinueButton.grab_focus()


func initialize(total_drag_time_seconds: float, player_turn_count: int) -> void:
	var formatted_drag_time_string: String = tr("TOTAL_DRAG_TIME").format({"time": "%0.1f" % total_drag_time_seconds})

	$MarginContainer/VBoxContainer/DragTimeLabel.text = formatted_drag_time_string

	var formatted_turn_count_string: String = tr("TURN_COUNT").format({"count": player_turn_count})

	$MarginContainer/VBoxContainer/TurnCountLabel.text = formatted_turn_count_string


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_inside_tree():
		_play_entrance()


# Dim in the backdrop and pop the panel, Terra Battle results style
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


func _on_ContinueButton_pressed() -> void:
	emit_signal("continue_button_pressed")


func _on_VictoryScreen_visibility_changed() -> void:
	$CPUParticles2D.emitting = visible
