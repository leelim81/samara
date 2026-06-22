extends StackBasedMenuScreen


@export var battle_button_container_packed_scene: PackedScene


func _ready() -> void:
	_create_buttons_for_unlocked_chapters()
	
	_set_focus()


func on_load() -> void:
	super.on_load()
	
	_set_focus()


func _set_focus() -> void:
	$MarginContainer/VBoxContainer/HBoxContainer/SquadButton.grab_focus()


func _create_buttons_for_unlocked_chapters() -> void:
	for child in $MarginContainer/VBoxContainer/VBoxContainer2.get_children():
		child.queue_free()
	
	var save_data: SaveData = GameData.save_data
	
	for unlocked_chapter in save_data.unlocked_chapters:
		var container: Control = battle_button_container_packed_scene.instantiate()
		
		var chapter_data: ChapterData = save_data.find_chapter_data_by_title(unlocked_chapter.title)

		if not chapter_data.locked:
			container.connect("pressed", Callable(self, "on_ChapterButton_pressed").bind(chapter_data))

		$MarginContainer/VBoxContainer/VBoxContainer2.add_child(container)

		container.set_values(chapter_data)


func _on_SquadButton_pressed() -> void:
	navigate("res://ui/pre_battle_menu/squad_menu.tscn")


func _on_CharactersButton_pressed() -> void:
	navigate("res://ui/pre_battle_menu/characters_menu.tscn")


func _on_QuitButton_pressed() -> void:
	change_scene_to_file("res://ui/main_menu/stack_based_main_menu.tscn")


func on_ChapterButton_pressed(chapter_data: ChapterData) -> void:
	change_scene_to_file("res://ui/cutscenes/script_cutscene.tscn", chapter_data)
