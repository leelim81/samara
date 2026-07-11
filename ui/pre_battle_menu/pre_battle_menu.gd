extends StackBasedMenuScreen


@export var battle_button_container_packed_scene: PackedScene

# EX / farming stages appear in the battle list once the player reaches this rank.
const EX_UNLOCK_RANK: int = 3
const _EX_LIST_PATH := "res://chapter_data/ex_stage_list.tres"


func _ready() -> void:
	_create_buttons_for_unlocked_chapters()

	_refresh_wallet()

	_set_focus()

	# Mobile-style bottom tabs: large glyph over a small label. Rarely used
	# destinations live in the More sheet.
	var nav: Node = $MarginContainer/VBoxContainer/NavBar

	ButtonIcons.apply_tab(nav.get_node("SquadButton"), "squad")
	ButtonIcons.apply_tab(nav.get_node("CharactersButton"), "figure")
	ButtonIcons.apply_tab(nav.get_node("MarketButton"), "scales")
	ButtonIcons.apply_tab(nav.get_node("ItemsButton"), "pouch")
	ButtonIcons.apply_tab(nav.get_node("MoreButton"), "more")


func on_load() -> void:
	super.on_load()
	
	_refresh_wallet()

	_set_focus()


func _refresh_wallet() -> void:
	$MarginContainer/VBoxContainer/WalletRow/Amount.text = str(GameData.save_data.coins)
	$MarginContainer/VBoxContainer/WalletRow/RankLabel.text = "%s %d" % [tr("RANK"), GameData.save_data.account_level()]


func _set_focus() -> void:
	$MarginContainer/VBoxContainer/NavBar/SquadButton.grab_focus()


# ---- The More sheet (rarely used destinations, folded behind the More tab) --

const _MORE_ROWS := [
	{"key": "BESTIARY", "icon": "book", "scene": "res://ui/bestiary_menu.tscn"},
	{"key": "HOW_TO_PLAY", "icon": "question", "scene": "res://ui/how_to_play_menu.tscn"},
	{"key": "SETTINGS", "icon": "gear", "scene": "res://ui/main_menu/settings_menu.tscn"},
	{"key": "RETURN_TO_MAIN_MENU", "icon": "door", "scene": ""},
]

const _AUDIO_BUTTON := preload("res://ui/audio_button.tscn")

var _more_sheet: Control = null


func _on_MoreButton_pressed() -> void:
	if _more_sheet != null:
		_close_more_sheet()
		return

	_more_sheet = Control.new()
	_more_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_more_sheet)

	# Tapping the dimmed backdrop closes the sheet.
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_more_scrim_input)
	_more_sheet.add_child(scrim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.106, 0.122, 0.149)
	style.border_color = Color(0.753, 0.627, 0.384, 0.8)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_more_sheet.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	for row in _MORE_ROWS:
		var button: Button = _AUDIO_BUTTON.instantiate()
		button.text = row.key
		button.custom_minimum_size = Vector2(0, 56)
		vbox.add_child(button)
		ButtonIcons.apply(button, row.icon)
		button.pressed.connect(_on_more_row_pressed.bind(row))

	vbox.get_child(0).grab_focus()

	# Slide up from the bottom edge.
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	panel.position.y += 26
	tween.tween_property(panel, "position:y", panel.position.y - 26, 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_more_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_more_sheet()


func _close_more_sheet() -> void:
	if _more_sheet != null:
		_more_sheet.queue_free()
		_more_sheet = null

		_set_focus()


func _on_more_row_pressed(row: Dictionary) -> void:
	_close_more_sheet()

	if row.scene == "":
		change_scene_to_file("res://ui/main_menu/stack_based_main_menu.tscn")
	else:
		navigate(row.scene)


func _unhandled_key_input(event: InputEvent) -> void:
	if _more_sheet != null and event.is_action_pressed("ui_cancel"):
		_close_more_sheet()

		get_viewport().set_input_as_handled()


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


func _on_ItemsButton_pressed() -> void:
	navigate("res://ui/inventory_menu.tscn")


func _on_MarketButton_pressed() -> void:
	navigate("res://ui/shop/shop_menu.tscn")


func on_ChapterButton_pressed(chapter_data: ChapterData) -> void:
	change_scene_to_file("res://ui/cutscenes/script_cutscene.tscn", chapter_data)
