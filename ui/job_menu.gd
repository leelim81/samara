extends StackBasedMenuScreen
# Jobs screen (Terra Battle: a character has up to 3 jobs, each with its own stats,
# skills, and artwork). Lists every job for one unit: the active one is highlighted,
# already-unlocked ones can be switched to for free, and the next locked one can be
# unlocked in order with coins + materials. Reached from the unit detail screen.
# The choice is stored on the Job (active_job / unlocked_jobs) and persisted.

@onready var _list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var _subtitle: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var _wallet: Label = $MarginContainer/VBoxContainer/WalletRow/Amount
@onready var _wallet_row: HBoxContainer = $MarginContainer/VBoxContainer/WalletRow
@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton

const _NAME_FONT := preload("res://assets/fonts/Exo2SemiBold.tres")
const _AUDIO_BUTTON := preload("res://ui/audio_button.tscn")
const _BTN_NORMAL := preload("res://assets/ui/btn_dark_normal.tres")
const _BTN_HOVER := preload("res://assets/ui/btn_dark_hover.tres")
const _BTN_PRESSED := preload("res://assets/ui/btn_dark_pressed.tres")

const _ACCENT := Color(0.86, 0.72, 0.42)
const _NEUTRAL := Color(0.863, 0.878, 0.894)
const _MUTED := Color(0.6, 0.64, 0.667)
const _DIM := Color(0.42, 0.45, 0.5)

# Role label per job index (job_name is the character name, shared across jobs).
const _ROLE_KEYS := ["JOB_ROLE_1", "JOB_ROLE_2", "JOB_ROLE_3"]

# Cost to unlock job 2 (index 1) then job 3 (index 2), added in order.
const _UNLOCK_COIN := [0, 3000, 8000]
const _UNLOCK_MATS := [{}, {"alloy": 4}, {"core": 2}]

var _job: Job = null
var _confirming_index: int = -1


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

	_confirming_index = -1
	_subtitle.text = tr(_job.job_name)
	_update_wallet()

	for child in _list.get_children():
		child.queue_free()

	for index in _job.job_count():
		_list.add_child(_make_card(index))


# Coins plus the two materials job unlocks consume, so a disabled unlock is legible.
func _update_wallet() -> void:
	_wallet.text = str(GameData.save_data.coins)

	var mats := _wallet_row.get_node_or_null("Materials")

	if mats == null:
		mats = Label.new()
		mats.name = "Materials"
		mats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mats.add_theme_font_size_override("font_size", 15)
		mats.add_theme_color_override("font_color", _MUTED)
		_wallet_row.add_child(mats)

	mats.text = "   %d %s    %d %s" % [
		GameData.save_data.item_count("alloy"), tr("ITEM_ALLOY"),
		GameData.save_data.item_count("core"), tr("ITEM_CORE"),
	]


func _card_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.122, 0.141, 0.173, 0.95)
	style.set_border_width_all(2 if active else 1)
	style.border_color = _ACCENT if active else Color(0.749, 0.627, 0.384, 0.35)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)

	return style


func _make_card(index: int) -> PanelContainer:
	var variant = load(Job.variant_path(_job.source_path, index + 1))

	var unlocked: bool = index < _job.unlocked_jobs
	var active: bool = index == _job.active_job
	var is_next: bool = index == _job.unlocked_jobs and index < _job.job_count()

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(active))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	card.add_child(hb)

	hb.add_child(_thumb(variant, unlocked))
	hb.add_child(_body(variant, index, unlocked, active))
	hb.add_child(_action(index, unlocked, active, is_next))

	return card


func _thumb(variant, unlocked: bool) -> TextureRect:
	var thumb := TextureRect.new()
	thumb.texture = variant.portrait
	thumb.custom_minimum_size = Vector2(60, 60)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb.modulate = Color.WHITE if unlocked else Color(0.4, 0.42, 0.47, 0.85)

	return thumb


func _body(variant, index: int, unlocked: bool, active: bool) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_theme_constant_override("separation", 3)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	body.add_child(title_row)

	var name_label := Label.new()
	name_label.text = tr(_ROLE_KEYS[index])
	name_label.add_theme_font_override("font", _NAME_FONT)
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", _ACCENT if active else (_NEUTRAL if unlocked else _DIM))
	title_row.add_child(name_label)

	var weapon_icon := TextureRect.new()
	weapon_icon.texture = load(Enums.WEAPON_TYPE_TEXTURES[variant.stats.weapon_type])
	weapon_icon.custom_minimum_size = Vector2(22, 22)
	weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weapon_icon.modulate = Color.WHITE if unlocked else _DIM
	title_row.add_child(weapon_icon)

	var stats_label := Label.new()
	stats_label.text = _stats_text(variant)
	stats_label.add_theme_font_size_override("font_size", 15)
	stats_label.add_theme_color_override("font_color", _MUTED if unlocked else _DIM)
	body.add_child(stats_label)

	var skills_label := Label.new()
	skills_label.text = _skills_text(variant)
	skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_label.add_theme_font_size_override("font_size", 14)
	skills_label.add_theme_color_override("font_color", Color(0.56, 0.63, 0.74) if unlocked else _DIM)
	body.add_child(skills_label)

	return body


# The job's stats at the unit's level, mirroring the awaken transform so the card
# matches the detail screen for an awakened unit.
func _stats_text(variant) -> String:
	var s = variant.stats.duplicate()
	s.uses_growth_curve = true

	if _job.awakened:
		s.health_percentage *= Job.AWAKEN_MULTIPLIER
		s.attack_percentage *= Job.AWAKEN_MULTIPLIER
		s.defense_percentage *= Job.AWAKEN_MULTIPLIER
		s.spiritual_attack_percentage *= Job.AWAKEN_MULTIPLIER
		s.spiritual_defense_percentage *= Job.AWAKEN_MULTIPLIER

	s.level = _job.level

	return "HP %d    ATK %d    DEF %d    S.ATK %d    S.DEF %d" % [
		s.health, s.attack, s.defense, s.spiritual_attack, s.spiritual_defense,
	]


func _skills_text(variant) -> String:
	var names := []

	for skill in variant.skills:
		names.append(tr(skill.skill_name))

	return ", ".join(names)


func _action(index: int, unlocked: bool, active: bool, is_next: bool) -> Control:
	if active:
		return _tag(tr("JOB_ACTIVE"), _ACCENT)

	if unlocked:
		return _button(tr("SWITCH"), _on_switch.bind(index), false)

	if is_next:
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)

		var price := Label.new()
		price.text = _cost_text(index)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.add_theme_font_size_override("font_size", 14)
		price.add_theme_color_override("font_color", _ACCENT)
		box.add_child(price)

		var affordable: bool = Purchase.can_afford(GameData.save_data, _UNLOCK_COIN[index], _UNLOCK_MATS[index])
		var button := _button(tr("UNLOCK"), Callable(), not affordable)
		button.pressed.connect(_on_unlock_pressed.bind(index, button))
		box.add_child(button)

		return box

	# Locked and not next in line: must unlock the previous job first.
	return _tag(tr("LOCKED"), _DIM)


func _tag(text: String, color: Color) -> Label:
	var tag := Label.new()
	tag.text = text
	tag.add_theme_font_override("font", _NAME_FONT)
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", color)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.custom_minimum_size = Vector2(108, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	return tag


func _button(text: String, callable: Callable, disabled: bool) -> Button:
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

	if callable.is_valid():
		button.pressed.connect(callable)

	return button


func _cost_text(index: int) -> String:
	var parts := ["%dc" % _UNLOCK_COIN[index]]

	for id in _UNLOCK_MATS[index]:
		parts.append("%d %s" % [_UNLOCK_MATS[index][id], tr("ITEM_" + id.to_upper())])

	return "  ".join(parts)


func _on_switch(index: int) -> void:
	_job.switch_job(index)
	GameData.save()

	_build()


func _on_unlock_pressed(index: int, button: Button) -> void:
	# Spends a rare material, so require a second tap to confirm.
	if _confirming_index != index:
		_confirming_index = index
		button.text = tr("UNLOCK_CONFIRM")

		return

	if Purchase.spend(GameData.save_data, _UNLOCK_COIN[index], _UNLOCK_MATS[index]):
		_job.unlock_next_job()
		GameData.save()

	_confirming_index = -1

	_build()


func _on_ReturnButton_pressed() -> void:
	go_back()
