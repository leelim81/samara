extends Button


signal fast_forward_toggled(enabled)

const ACTIVE_COLOR := Color(0.792157, 0.580392, 0.180392)
const IDLE_COLOR := Color(0.227451, 0.211765, 0.188235)


func _ready() -> void:
	toggled.connect(_on_toggled)

	add_theme_color_override("font_color", IDLE_COLOR)


func _on_toggled(is_pressed: bool) -> void:
	add_theme_color_override("font_color", ACTIVE_COLOR if is_pressed else IDLE_COLOR)

	$AudioStreamPlayer.play()

	emit_signal("fast_forward_toggled", is_pressed)
