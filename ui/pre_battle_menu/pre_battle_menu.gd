extends StackBasedMenuScreen


@export var battle_button_container_packed_scene: PackedScene

# EX / farming stages appear in the battle list once the player reaches this rank.
const EX_UNLOCK_RANK: int = 3
const _EX_LIST_PATH := "res://chapter_data/ex_stage_list.tres"


func _ready() -> void:
	_create_buttons_for_unlocked_chapters()

	_refresh_wallet()

	_set_focus()

	_maybe_auto_show_tutorial()

	# Gold glyphs on the nav grid (shared button icon set).
	var nav: Node = $MarginContainer/VBoxContainer/NavGrid

	ButtonIcons.apply(nav.get_node("SquadButton"), "squad")
	ButtonIcons.apply(nav.get_node("CharactersButton"), "figure")
	ButtonIcons.apply(nav.get_node("BestiaryButton"), "book")
	ButtonIcons.apply(nav.get_node("ItemsButton"), "pouch")
	ButtonIcons.apply(nav.get_node("MarketButton"), "scales")
	ButtonIcons.apply(nav.get_node("HowToPlayButton"), "question")
	ButtonIcons.apply(nav.get_node("QuitButton"), "door")


func on_load() -> void:
	super.on_load()
	
	_refresh_wallet()

	_set_focus()


func _refresh_wallet() -> void:
	$MarginContainer/VBoxContainer/WalletRow/Amount.text = str(GameData.save_data.coins)
	$MarginContainer/VBoxContainer/WalletRow/RankLabel.text = "%s %d" % [tr("RANK"), GameData.save_data.account_level()]


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

	_add_ex_stages(list, save_data)


# Appends the EX / farming stages below the story chapters, once unlocked. They
# launch straight into battle (no story cutscenes) and never advance the story.
func _add_ex_stages(list: VBoxContainer, save_data: SaveData) -> void:
	if save_data.account_level() < EX_UNLOCK_RANK:
		return

	var ex_list: ChapterList = load(_EX_LIST_PATH)

	if ex_list == null:
		return

	var header := Label.new()
	header.text = tr("EX_STAGES")
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.custom_minimum_size = Vector2(0, 48)
	list.add_child(header)

	for chapter_data in ex_list.chapters:
		var container: Control = battle_button_container_packed_scene.instantiate()

		container.connect("pressed", Callable(self, "on_ExStagePressed").bind(chapter_data))

		list.add_child(container)

		container.set_values(chapter_data)


func on_ExStagePressed(chapter_data: ChapterData) -> void:
	change_scene_to_file(chapter_data.battle_scene_path, chapter_data)


func _on_SquadButton_pressed() -> void:
	navigate("res://ui/pre_battle_menu/squad_menu.tscn")


func _on_CharactersButton_pressed() -> void:
	navigate("res://ui/pre_battle_menu/characters_menu.tscn")


func _on_HowToPlayButton_pressed() -> void:
	navigate("res://ui/how_to_play_menu.tscn")


func _on_BestiaryButton_pressed() -> void:
	navigate("res://ui/bestiary_menu.tscn")


func _on_ItemsButton_pressed() -> void:
	navigate("res://ui/inventory_menu.tscn")


func _on_MarketButton_pressed() -> void:
	navigate("res://ui/shop/shop_menu.tscn")


func _on_QuitButton_pressed() -> void:
	change_scene_to_file("res://ui/main_menu/stack_based_main_menu.tscn")


func on_ChapterButton_pressed(chapter_data: ChapterData) -> void:
	change_scene_to_file("res://ui/cutscenes/script_cutscene.tscn", chapter_data)
