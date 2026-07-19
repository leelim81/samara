extends StackBasedMenuScreen


@export var settings_scene: String # (String, FILE, "*.tscn")

var _last_active_button: Button = null

@onready var _quit_button: Button = $MarginContainer/VBoxContainer2/VBoxContainer/QuitButton
@onready var _start_button: Button = $MarginContainer/VBoxContainer2/VBoxContainer/StartButton
@onready var _gallery_button: Button = $MarginContainer/VBoxContainer2/VBoxContainer/GalleryButton


func _ready() -> void:
	if OS.get_name() == "Web":
		_quit_button.hide()

	_set_focus()

	# Show "Continue" instead of "Start" once the player has progress on disk.
	if GameData.has_save_file():
		_start_button.text = "CONTINUE"

	ButtonIcons.apply(_start_button, "battle")
	ButtonIcons.apply($MarginContainer/VBoxContainer2/VBoxContainer/SettingsButton, "gear")
	ButtonIcons.apply(_quit_button, "door")

	# The art Gallery is a debug-only tool, gated on the global DEBUG flag.
	_gallery_button.visible = Global.DEBUG

	if Global.DEBUG:
		ButtonIcons.apply(_gallery_button, "book")


func on_load() -> void:
	super.on_load()
	
	_set_focus()


func _set_focus() -> void:
	if _last_active_button != null:
		_last_active_button.grab_focus()
	else:
		_start_button.grab_focus()
		
		_last_active_button = _start_button


func _on_StartButton_pressed() -> void:
	change_scene_to_file("res://ui/pre_battle_menu/stack_based_pre_battle_menu.tscn")


func _on_SettingsButton_pressed() -> void:
	_last_active_button = $MarginContainer/VBoxContainer2/VBoxContainer/SettingsButton

	navigate(settings_scene)


func _on_GalleryButton_pressed() -> void:
	_last_active_button = _gallery_button

	navigate("res://ui/gallery_menu.tscn")


func _on_QuitButton_pressed() -> void:
	get_tree().quit()


func _on_TitleScreen_tree_entered() -> void:
	TranslationServer.set_locale(TranslationServer.get_locale())
