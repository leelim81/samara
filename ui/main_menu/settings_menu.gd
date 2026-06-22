extends StackBasedMenuScreen


@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton
@onready var _drag_mode_check: CheckButton = $MarginContainer/VBoxContainer/VBoxContainer/CheckButton


func on_load() -> void:
	super.on_load()

	# Reflect the saved drag mode (checked = click-to-move, unchecked = hold).
	_drag_mode_check.button_pressed = GameData.save_data.drag_mode == Enums.DragMode.CLICK

	_return_button.grab_focus()


func _on_DragModeCheckButton_toggled(is_pressed: bool) -> void:
	GameData.save_data.drag_mode = Enums.DragMode.CLICK if is_pressed else Enums.DragMode.HOLD

	GameData.save()


func _on_ReturnButton_pressed() -> void:
	go_back()


func _on_VolumeSlider_on_changed(bus_name: String, volume: float) -> void:
	if bus_name == "Sound effects":
		GameData.save_data.sound_effects_volume = volume
	else:
		GameData.save_data.music_volume = volume

	GameData.save()
