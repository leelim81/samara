extends SceneTree
func _init():
	var en = load("res://text/text.en.translation")
	if en == null:
		push_error("load failed"); quit(1); return
	for k in ["BAHL", "CHAR_PANTHER_HEAD", "DAIANA", "CHAR_THE_WISDOM_STAR", "CHAR_THE_WITCH"]:
		print(k, " => ", en.get_message(k))
	print("locale=", en.locale, " count=", en.get_message_count())
	quit(0)
