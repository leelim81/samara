extends TextureProgressBar


var _tween: Tween


func _on_Job_health_changed(current_health: int, max_health: int) -> void:
	var next_value: int = int(max_value * current_health / max_health)

	if _tween != null:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "value", next_value, 0.25) \
			.set_trans(Tween.TRANS_LINEAR)
