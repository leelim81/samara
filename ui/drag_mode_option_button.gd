extends OptionButton


const CLICK_MODE_INDEX: int = 0
const HOLD_MODE_INDEX: int = 1

signal drag_mode_changed(drag_mode)


func _ready() -> void:
	# Items are built in code: the Godot 3 scene "items" property is not
	# understood by Godot 4's OptionButton.
	clear()
	add_icon_item(preload("res://assets/ui/click.png"), "CLICK", CLICK_MODE_INDEX)
	add_icon_item(preload("res://assets/ui/drag.png"), "HOLD", HOLD_MODE_INDEX)

	var save_data: SaveData = GameData.save_data

	if save_data.drag_mode == Enums.DragMode.CLICK:
		select(CLICK_MODE_INDEX)
	else:
		select(HOLD_MODE_INDEX)


func _on_DragModeOptionButton_item_selected(index: int) -> void:
	_play_sound()
	
	if index == CLICK_MODE_INDEX:
		emit_signal("drag_mode_changed", Enums.DragMode.CLICK)
	else:
		emit_signal("drag_mode_changed", Enums.DragMode.HOLD)


func _on_DragModeOptionButton_pressed() -> void:
	_play_sound()


func _play_sound() -> void:
	$AudioStreamPlayer.play()
