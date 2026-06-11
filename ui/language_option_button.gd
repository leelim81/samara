extends OptionButton


const LANGUAGE_EN_INDEX: int = 0
const LANGUAGE_ES_INDEX: int = 1


func _ready() -> void:
	# Items are built in code: the Godot 3 scene "items" property is not
	# understood by Godot 4's OptionButton.
	clear()
	add_item("English", LANGUAGE_EN_INDEX)
	add_item("Español", LANGUAGE_ES_INDEX)

	var locale = TranslationServer.get_locale()

	if locale.begins_with("es"):
		select(LANGUAGE_ES_INDEX)
	else:
		select(LANGUAGE_EN_INDEX)


func _on_LanguageOptionButton_item_selected(index: int) -> void:
	match(index):
		LANGUAGE_EN_INDEX:
			TranslationServer.set_locale("en")
		LANGUAGE_ES_INDEX:
			TranslationServer.set_locale("es")
