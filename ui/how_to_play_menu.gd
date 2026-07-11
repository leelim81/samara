extends StackBasedMenuScreen
# Terra-Battle-style "How to Play": a scrollable primer on the four core battle
# mechanics. Shown once automatically on the first visit to the pre-battle menu
# (see pre_battle_menu.gd) and always reachable from its own button. Read-only.


@onready var _sections: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton

const _TITLE_FONT := preload("res://assets/fonts/EBGaramond24.tres")

# (title key, body key) for each mechanic, in teaching order.
const _SECTIONS: Array = [
	["HOWTO_PINCER_TITLE", "HOWTO_PINCER_BODY"],
	["HOWTO_CHAIN_TITLE", "HOWTO_CHAIN_BODY"],
	["HOWTO_POWER_TITLE", "HOWTO_POWER_BODY"],
	["HOWTO_TIMER_TITLE", "HOWTO_TIMER_BODY"],
]

# Warm gold for section titles, muted ink for body copy (matches the menus).
const _ACCENT_COLOR: Color = Color(0.82, 0.69, 0.44)
const _BODY_COLOR: Color = Color(0.7, 0.74, 0.78)


func _ready() -> void:
	_build_sections()

	ButtonIcons.apply(_return_button, "return")


func on_load() -> void:
	super.on_load()

	_return_button.grab_focus()


func on_add_to_tree(_data: Object) -> void:
	# Mark the primer seen the moment it is shown, so it never auto-opens again.
	if GameData.save_data != null and not GameData.save_data.tutorial_seen:
		GameData.save_data.tutorial_seen = true

		GameData.save()


func _build_sections() -> void:
	for child in _sections.get_children():
		child.queue_free()

	for pair in _SECTIONS:
		_sections.add_child(_make_section(pair[0], pair[1]))


func _make_section(title_key: String, body_key: String) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = tr(title_key)
	title.add_theme_font_override("font", _TITLE_FONT)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", _ACCENT_COLOR)
	block.add_child(title)

	var body := Label.new()
	body.text = tr(body_key)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", _BODY_COLOR)
	block.add_child(body)

	return block


func _on_ReturnButton_pressed() -> void:
	go_back()
