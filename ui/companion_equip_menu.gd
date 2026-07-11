extends StackBasedMenuScreen
# Equip or acquire a companion for one unit. Lists every companion: the unit's
# current one is highlighted, owned ones can be equipped, and unowned ones can be
# bought with coins (via Purchase). Reached from the unit detail screen; the
# chosen companion is stored per unit (Job.uid) and applied in battle.

@onready var _list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var _subtitle: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var _wallet: Label = $MarginContainer/VBoxContainer/WalletRow/Amount
@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton

const _CATALOG_PATH := "res://companions/companion_catalog.tres"
const _NAME_FONT := preload("res://assets/fonts/Exo2SemiBold.tres")
const _AUDIO_BUTTON := preload("res://ui/audio_button.tscn")
const _BTN_NORMAL := preload("res://assets/ui/btn_dark_normal.tres")
const _BTN_HOVER := preload("res://assets/ui/btn_dark_hover.tres")
const _BTN_PRESSED := preload("res://assets/ui/btn_dark_pressed.tres")

const _ACCENT := Color(0.86, 0.72, 0.42)
const _NEUTRAL := Color(0.863, 0.878, 0.894)
const _MUTED := Color(0.6, 0.64, 0.667)

var _job: Job = null


func _ready() -> void:
	ButtonIcons.apply(_return_button, "return")


func on_add_to_tree(data: Object) -> void:
	if data is Job:
		_job = data

	_build()


func on_load() -> void:
	super.on_load()

	_return_button.grab_focus()


func _build() -> void:
	if _job == null:
		return

	_wallet.text = str(GameData.save_data.coins)
	_subtitle.text = tr(_job.job_name)

	for child in _list.get_children():
		child.queue_free()

	if _job.companion != null:
		_list.add_child(_make_remove_row())

	var catalog = load(_CATALOG_PATH)

	if catalog == null:
		return

	for companion in catalog.companions:
		_list.add_child(_make_row(companion))


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.122, 0.141, 0.173, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.749, 0.627, 0.384, 0.35)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)

	return style


func _make_row(companion) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	card.add_child(hb)

	var equipped: bool = _is_equipped(companion)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_theme_constant_override("separation", 3)
	hb.add_child(body)

	var name_label := Label.new()
	name_label.text = tr(companion.companion_name)
	name_label.add_theme_font_override("font", _NAME_FONT)
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", _ACCENT if equipped else _NEUTRAL)
	body.add_child(name_label)

	var bonus_label := Label.new()
	bonus_label.text = _bonus_text(companion)
	bonus_label.add_theme_font_size_override("font_size", 15)
	bonus_label.add_theme_color_override("font_color", _MUTED)
	body.add_child(bonus_label)

	if equipped:
		var tag := Label.new()
		tag.text = tr("EQUIPPED")
		tag.add_theme_font_override("font", _NAME_FONT)
		tag.add_theme_font_size_override("font_size", 16)
		tag.add_theme_color_override("font_color", _ACCENT)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(tag)
	elif GameData.save_data.is_companion_owned(companion.resource_path):
		var equip_button := _action_button(tr("EQUIP"), _on_equip.bind(companion), false)
		ButtonIcons.apply(equip_button, "link")
		hb.add_child(equip_button)
	else:
		var price := Label.new()
		price.text = "%dc" % companion.shop_price
		price.add_theme_font_override("font", _NAME_FONT)
		price.add_theme_font_size_override("font_size", 18)
		price.add_theme_color_override("font_color", _ACCENT)
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(price)

		var can_buy: bool = companion.shop_price > 0 and Purchase.can_afford(GameData.save_data, companion.shop_price)
		var buy_button := _action_button(tr("BUY"), _on_buy.bind(companion), not can_buy)
		ButtonIcons.apply(buy_button, "buy")
		hb.add_child(buy_button)

	return card


func _make_remove_row() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	card.add_child(hb)

	var label := Label.new()
	label.text = tr("NO_COMPANION")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_override("font", _NAME_FONT)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", _MUTED)
	hb.add_child(label)

	var unequip_button := _action_button(tr("UNEQUIP"), _on_unequip, false)
	ButtonIcons.apply(unequip_button, "unlink")
	hb.add_child(unequip_button)

	return card


func _action_button(text: String, callable: Callable, disabled: bool) -> Button:
	var button = _AUDIO_BUTTON.instantiate()
	button.text = text
	button.pop_on_hover = false
	button.custom_minimum_size = Vector2(108, 46)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _BTN_NORMAL)
	button.add_theme_stylebox_override("hover", _BTN_HOVER)
	button.add_theme_stylebox_override("pressed", _BTN_PRESSED)
	button.add_theme_stylebox_override("focus", _BTN_HOVER)
	button.add_theme_stylebox_override("disabled", _BTN_NORMAL)
	button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.62))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.54))
	button.disabled = disabled
	button.pressed.connect(callable)

	return button


func _is_equipped(companion) -> bool:
	return _job.companion != null and _job.companion.resource_path == companion.resource_path


# Companion bonuses scale with the unit's level (the wiki growth curve), matching
# the display on the unit detail screen.
func _bonus_text(companion) -> String:
	var growth: float = pow(float(clampi(_job.level, 1, Leveling.MAX_LEVEL)), 0.53) / pow(float(Leveling.MAX_LEVEL), 0.53)

	var parts := []

	if companion.health_bonus != 0:
		parts.append("+%d HP" % int(round(companion.health_bonus * growth)))
	if companion.attack_bonus != 0:
		parts.append("+%d ATK" % int(round(companion.attack_bonus * growth)))
	if companion.defense_bonus != 0:
		parts.append("+%d DEF" % int(round(companion.defense_bonus * growth)))
	if companion.spiritual_attack_bonus != 0:
		parts.append("+%d S.ATK" % int(round(companion.spiritual_attack_bonus * growth)))
	if companion.spiritual_defense_bonus != 0:
		parts.append("+%d S.DEF" % int(round(companion.spiritual_defense_bonus * growth)))

	return ", ".join(parts) if not parts.is_empty() else tr("NO_BONUS")


func _on_equip(companion) -> void:
	_job.companion = companion
	GameData.save_data.equipped_companions[_job.uid] = companion.resource_path
	GameData.save()

	_build()


func _on_unequip() -> void:
	_job.companion = null
	GameData.save_data.equipped_companions[_job.uid] = ""
	GameData.save()

	_build()


func _on_buy(companion) -> void:
	if Purchase.spend(GameData.save_data, companion.shop_price):
		GameData.save_data.add_owned_companion(companion.resource_path)
		GameData.save()

		_build()


func _on_ReturnButton_pressed() -> void:
	go_back()
