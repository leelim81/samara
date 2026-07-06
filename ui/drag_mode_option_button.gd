extends Button
# A single tap toggle for the tile-drag control scheme, sitting on the battle
# HUD next to Pause / Fast-forward. Web players use tap-to-move (CLICK); phone
# players use hold-and-drag (HOLD). One button, two states, no dropdown: the
# icon shows the mode you are currently in and a tap flips it.


signal drag_mode_changed(drag_mode)

const _CLICK_ICON := preload("res://assets/ui/click.png")
const _DRAG_ICON := preload("res://assets/ui/drag.png")


func _ready() -> void:
	toggle_mode = true

	var is_hold: bool = GameData.save_data.drag_mode == Enums.DragMode.HOLD

	# Reflect the saved mode without re-emitting on startup.
	set_pressed_no_signal(is_hold)
	_refresh_visual(is_hold)


func _on_toggled(is_pressed: bool) -> void:
	_play_sound()
	_refresh_visual(is_pressed)

	var mode: int = Enums.DragMode.HOLD if is_pressed else Enums.DragMode.CLICK

	emit_signal("drag_mode_changed", mode)


func _refresh_visual(is_hold: bool) -> void:
	# Tap-ripples glyph = tap-to-move, motion-arrow glyph = hold-and-drag. The
	# pressed-in look (toggle on) reinforces that hold mode is engaged.
	icon = _DRAG_ICON if is_hold else _CLICK_ICON

	tooltip_text = "%s  /  %s" % [tr("TAP"), tr("HOLD")]


func _play_sound() -> void:
	$AudioStreamPlayer.play()
