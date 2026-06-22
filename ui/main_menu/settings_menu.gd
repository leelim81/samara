extends StackBasedMenuScreen


@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton


func on_load() -> void:
	super.on_load()
	
	_return_button.grab_focus()


func _on_ReturnButton_pressed() -> void:
	go_back()


func _on_VolumeSlider_on_changed(bus_name: String, volume: float) -> void:
	if bus_name == "Sound effects":
		GameData.save_data.sound_effects_volume = volume
	else:
		GameData.save_data.music_volume = volume

	GameData.save()
