extends Line2D
# Gentle alpha pulse so combo links read as live energy, Terra Battle style


func _ready() -> void:
	var pulse_tween := create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(self, "modulate:a", 0.65, 0.45) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(self, "modulate:a", 1.0, 0.45) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
