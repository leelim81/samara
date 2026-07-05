extends StackBasedMenuScreen


@export var battle_button_container_packed_scene: PackedScene


func _ready() -> void:
	_create_buttons_for_unlocked_chapters()

	_refresh_wallet()

	_set_focus()

	_maybe_auto_show_tutorial()


func on_load() -> void:
	super.on_load()
	
	_refresh_wallet()

	_set_focus()


func _refresh_wallet() -> void:
	$MarginContainer/VBoxContainer/WalletRow/Amount.text = str(GameData.save_data.coins)


func _set_focus() -> void:
	$MarginContainer/VBoxContainer/NavGrid/SquadButton.grab_focus()


# Shows the How to Play primer once, on the player's first arrival at this hub.
func _maybe_auto_show_tutorial() -> void:
	if GameData.save_data == null or GameData.save_data.tutorial_seen:
		return

	# Defer past this frame so the stack manager has connected our
	# navigation_requested signal (the parent readies after this child).
	call_deferred("_auto_show_tutorial")


func _auto_show_tutorial() -> void:
	if GameData.save_data == null or GameData.save_data.tutorial_seen:
		return

	# Let the entry transition settle before opening the primer.
	await get_tree().create_timer(0.35).timeout

	if is_inside_tree() and GameData.save_data != null and not GameData.save_data.tutorial_seen:
		navigate("res://ui/how_to_play_menu.tscn")


func _create_buttons_for_unlocked_chapters() -> void:
	var list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer2

	for child in list.get_children():
		child.queue_free()

	var save_data: SaveData = GameData.save_data

	for unlocked_chapter in save_data.unlocked_chapters:
		var container: Control = battle_button_container_packed_scene.instantiate()

		var chapter_data: ChapterData = save_data.find_chapter_data_by_title(unlocked_chapter.title)

		if not chapter_data.locked:
			container.connect("pressed", Callable(self, "on_ChapterButton_pressed").bind(chapter_data))

		list.add_child(container)

		container.set_values(chapter_data)


func _on_SquadButton_pressed() -> void:
	navigate("res://ui/pre_battle_menu/squad_menu.tscn")


func _on_CharactersButton_pressed() -> void:
	navigate("res://ui/pre_battle_menu/characters_menu.tscn")


func _on_HowToPlayButton_pressed() -> void:
	navigate("res://ui/how_to_play_menu.tscn")


func _on_BestiaryButton_pressed() -> void:
	navigate("res://ui/bestiary_menu.tscn")


func _on_QuitButton_pressed() -> void:
	change_scene_to_file("res://ui/main_menu/stack_based_main_menu.tscn")


func on_ChapterButton_pressed(chapter_data: ChapterData) -> void:
	change_scene_to_file("res://ui/cutscenes/script_cutscene.tscn", chapter_data)
