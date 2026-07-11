extends StackBasedMenuScreen
# The Market: spend coins on upgrade materials. A coin sink that feeds the unit
# upgrades added later (metamorphosis, job changes). Buying goes through the
# Purchase helper; BUY buttons disable when the player cannot afford them.

@onready var _list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var _wallet: Label = $MarginContainer/VBoxContainer/WalletRow/Amount
@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton

const _MATERIAL_LIST_PATH := "res://items/material_list.tres"
const _NAME_FONT := preload("res://assets/fonts/Exo2SemiBold.tres")
const _AUDIO_BUTTON := preload("res://ui/audio_button.tscn")
const _BTN_NORMAL := preload("res://assets/ui/btn_dark_normal.tres")
const _BTN_HOVER := preload("res://assets/ui/btn_dark_hover.tres")
const _BTN_PRESSED := preload("res://assets/ui/btn_dark_pressed.tres")

const _RARITY_COLORS := {
	1: Color(0.72, 0.75, 0.8),
	2: Color(0.8, 0.66, 0.44),
	3: Color(0.45, 0.75, 0.9),
	4: Color(0.72, 0.56, 0.9),
	5: Color(0.92, 0.78, 0.42),
}


func _ready() -> void:
	_build()

	ButtonIcons.apply(_return_button, "return")


func on_add_to_tree(_data: Object) -> void:
	_build()


func on_load() -> void:
	super.on_load()

	_return_button.grab_focus()


func _build() -> void:
	_refresh_wallet()

	for child in _list.get_children():
		child.queue_free()

	var registry = load(_MATERIAL_LIST_PATH)

	if registry == null:
		return

	for item in registry.items:
		if item.shop_price <= 0:
			continue

		_list.add_child(_make_row(item))


func _refresh_wallet() -> void:
	_wallet.text = str(GameData.save_data.coins)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.122, 0.141, 0.173, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.749, 0.627, 0.384, 0.35)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)

	return style


func _make_row(item) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	card.add_child(hb)

	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = Vector2(52, 52)
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
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", _RARITY_COLORS.get(item.rarity, Color.WHITE))
	body.add_child(name_label)

	var owned_label := Label.new()
	owned_label.text = "%s %d" % [tr("OWNED"), GameData.save_data.item_count(item.id)]
	owned_label.add_theme_font_size_override("font_size", 15)
	owned_label.add_theme_color_override("font_color", Color(0.6, 0.64, 0.667))
	body.add_child(owned_label)

	var price_label := Label.new()
	price_label.text = "%dc" % item.shop_price
	price_label.add_theme_font_override("font", _NAME_FONT)
	price_label.add_theme_font_size_override("font_size", 19)
	price_label.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42, 1))
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(price_label)

	var buy := _AUDIO_BUTTON.instantiate()
	buy.text = tr("BUY")
	ButtonIcons.apply(buy, "buy")
	buy.pop_on_hover = false
	buy.custom_minimum_size = Vector2(104, 46)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.add_theme_font_size_override("font_size", 16)
	buy.add_theme_stylebox_override("normal", _BTN_NORMAL)
	buy.add_theme_stylebox_override("hover", _BTN_HOVER)
	buy.add_theme_stylebox_override("pressed", _BTN_PRESSED)
	buy.add_theme_stylebox_override("focus", _BTN_HOVER)
	buy.add_theme_stylebox_override("disabled", _BTN_NORMAL)
	buy.add_theme_color_override("font_color", Color(0.9, 0.85, 0.62))
	buy.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.54))
	buy.disabled = not Purchase.can_afford(GameData.save_data, item.shop_price)
	buy.pressed.connect(_on_buy_pressed.bind(item))
	hb.add_child(buy)

	return card


func _on_buy_pressed(item) -> void:
	if Purchase.spend(GameData.save_data, item.shop_price):
		GameData.save()

		_build()


func _on_ReturnButton_pressed() -> void:
	go_back()
