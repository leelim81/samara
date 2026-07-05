extends Button

class_name AudioButton

# Small buttons pop on hover; large ones (a full chapter card) shouldn't —
# the scale looks like the whole cell zooming. Opt out per instance.
@export var pop_on_hover: bool = true


func _ready() -> void:
	mouse_entered.connect(_on_hover)
	focus_entered.connect(_on_hover)


func _on_Button_pressed() -> void:
	$PressedAudio.play()


# Subtle pop on hover/focus for tactile feedback.
func _on_hover() -> void:
	if disabled or not pop_on_hover:
		return

	pivot_offset = size / 2.0

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.08) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_SINE)
