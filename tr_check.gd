extends SceneTree
func _initialize() -> void:
	print("locale: ", TranslationServer.get_locale())
	print("loaded locales: ", TranslationServer.get_loaded_locales())
	print("GIVE_UP -> ", tr("GIVE_UP"))
	print("WEE_ORBLING -> ", tr("WEE_ORBLING"))
	quit(0)
