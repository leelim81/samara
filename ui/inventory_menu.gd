extends StackBasedMenuScreen
# Item inventory: the materials the player has collected from battle, shown with
# icon, name, description, count, and a rarity tint. Read-only in this build;
# materials are spent in the shop.

@onready var _list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var _header: Label = $MarginContainer/VBoxContainer/HeaderLabel
@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton

const _MATERIAL_LIST_PATH := "res://items/material_list.tres"
const _NAME_FONT := preload("res://assets/fonts/Exo2SemiBold.tres")

const _RARITY_COLORS := {
	1: Color(0.72, 0.75, 0.8),
	2: Color(0.8, 0.66, 0.44),
	3: Color(0.45, 0.75, 0.9),
	4: Color(0.72, 0.56, 0.9),
	5: Color(0.92, 0.78, 0.42),
}


func _ready() -> void:
	_build()


func on_add_to_tree(_data: Object) -> void:
	_build()


func on_load() -> void:
	super.on_load()

	_return_button.grab_focus()


func _build() -> void:
	for child in _list.get_children():
		child.queue_free()

	var registry = load(_MATERIAL_LIST_PATH)
	var save_data: SaveData = GameData.save_data

	var owned := []

	if registry != null and save_data != null:
		for item in registry.items:
			var count: int = save_data.item_count(item.id)

			if count > 0:
				owned.append({"item": item, "count": count})

	owned.sort_custom(func(a, b): return a.item.sort_order < b.item.sort_order)

	if owned.is_empty():
		_list.add_child(_make_empty())
		_header.text = tr("ITEMS")
		return

	for entry in owned:
		_list.add_child(_make_row(entry.item, entry.count))

	_header.text = "%s  (%d)" % [tr("ITEMS"), owned.size()]


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.122, 0.141, 0.173, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.749, 0.627, 0.384, 0.35)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)

	return style


func _make_row(item, count: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	card.add_child(hb)

	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(icon)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_theme_constant_override("separation", 3)
	hb.add_child(body)

	var name_label := Label.new()
	name_label.text = tr(item.name_key)
	name_label.add_theme_font_override("font", _NAME_FONT)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", _RARITY_COLORS.get(item.rarity, Color.WHITE))
	body.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = tr(item.description_key)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.64, 0.667))
	body.add_child(desc_label)

	var count_label := Label.new()
	count_label.text = "x%d" % count
	count_label.add_theme_font_override("font", _NAME_FONT)
	count_label.add_theme_font_size_override("font_size", 22)
	count_label.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42, 1))
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(count_label)

	return card


func _make_empty() -> Label:
	var label := Label.new()
	label.text = tr("INVENTORY_EMPTY")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.5, 0.54, 0.6))
	label.custom_minimum_size = Vector2(0, 160)
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	return label


func _on_ReturnButton_pressed() -> void:
	go_back()
