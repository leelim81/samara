extends Button


signal fast_forward_toggled(enabled)

const ACTIVE_COLOR := Color(0.98, 0.85, 0.45)
const IDLE_COLOR := Color(0.92, 0.89, 0.82)


func _ready() -> void:
	toggled.connect(_on_toggled)

	add_theme_color_override("font_color", IDLE_COLOR)


func _on_toggled(is_pressed: bool) -> void:
	add_theme_color_override("font_color", ACTIVE_COLOR if is_pressed else IDLE_COLOR)

	$AudioStreamPlayer.play()

	emit_signal("fast_forward_toggled", is_pressed)
