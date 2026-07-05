extends StackBasedMenuScreen


@export var skill_pill_packed_scene: PackedScene
@export var status_row_packed_scene: PackedScene

@onready var _name_label: Label = $Margin/Root/NameLabel
@onready var _art: TextureRect = $Margin/Root/Header/FullArt
@onready var _token: TextureRect = $Margin/Root/Header/Info/ThumbRow/JobThumb/Token
@onready var _weapon_icon: TextureRect = $Margin/Root/Header/Info/ThumbRow/ThumbMeta/SpeciesRow/WeaponIcon
@onready var _species_label: Label = $Margin/Root/Header/Info/ThumbRow/ThumbMeta/SpeciesRow/SpeciesLabel
@onready var _lv_label: Label = $Margin/Root/Header/Info/ThumbRow/ThumbMeta/LVLabel
@onready var _hp_value: Label = $Margin/Root/Header/Info/HPBlock/HPRow/HPValue
@onready var _hp_bar: ProgressBar = $Margin/Root/Header/Info/HPBlock/HPBar
@onready var _atk_value: Label = $Margin/Root/Header/Info/StatsGrid/AtkStat/Value
@onready var _def_value: Label = $Margin/Root/Header/Info/StatsGrid/DefStat/Value
@onready var _satk_value: Label = $Margin/Root/Header/Info/StatsGrid/SatkStat/Value
@onready var _sdef_value: Label = $Margin/Root/Header/Info/StatsGrid/SdefStat/Value
@onready var _skills_vbox: VBoxContainer = $Margin/Root/SkillsScroll/SkillsVBox
@onready var _skills_header: Label = $Margin/Root/SkillsHeader
@onready var _return_button: Button = $Margin/Root/ReturnButton

# Outer Heaven species relabel: raw unit_type -> display (see docs/outer_heaven_bible.md).
# Heroes are Deviants (the mispredicted) or Spirits; enemies are Beasts / Machines.
# The only STONEFOLK/LIZARDFOLK units are heroes - enemy stone/lizard units are MONSTER.
const _SPECIES: Dictionary = {
	"HUMAN": "Deviant",
	"STONEFOLK": "Deviant",
	"ANIMAL_SPIRIT": "Spirit",
	"LIZARDFOLK": "Spirit",
	"MONSTER": "Beast",
	"HANIWA": "Machine",
}

# Created lazily and reused across initialize() calls.
var _element_label: Label = null
var _exp_label: Label = null
var _desc_label: Label = null
var _luck_label: Label = null

# The job currently shown, cached so returning from a pushed screen (e.g. the
# companion equip menu) re-renders it without needing the data passed again.
var _current_job: Job = null


# Called from squad menu
func initialize(job: Job, level: int) -> void:
	# Show activation rate, is not in battle, don't ignore locked skills
	initialize_from_data(job, job.stats, null, level, job.skills, [], true, false, false)


func initialize_from_data(job: Job, base_stats: Stats, current_stats: Stats, level: int, skills: Array, status_effects: Array, can_show_activation_rate: bool, is_in_battle: bool, can_ignore_locked_skills: bool) -> void:
	_set_focus()

	for child in _skills_vbox.get_children():
		child.queue_free()

	_name_label.text = tr(job.job_name)
	_art.texture = job.full_portrait
	_token.texture = job.portrait

	_species_label.text = _SPECIES.get(base_stats.unit_type, base_stats.unit_type.capitalize())
	_weapon_icon.texture = load(Enums.WEAPON_TYPE_TEXTURES[base_stats.weapon_type])

	_lv_label.text = "LV %d" % level

	_update_element_label(base_stats.attribute)
	_update_luck_label(job)
	_update_exp_label(job, level)
	_update_train_button(job, is_in_battle)
	_update_awaken_button(job)
	_update_desc_label(job)

	# In battle the panel reflects the unit's live stats; otherwise its base
	var display_stats: Stats = current_stats if (is_in_battle and current_stats != null) else base_stats

	if is_in_battle and current_stats != null:
		_hp_value.text = "%d / %d" % [current_stats.health, base_stats.health]
		_hp_bar.value = 100.0 * float(current_stats.health) / max(1.0, float(base_stats.health))
	else:
		_hp_value.text = str(base_stats.health)
		_hp_bar.value = 100.0

	_atk_value.text = str(display_stats.attack)
	_def_value.text = str(display_stats.defense)
	_satk_value.text = str(display_stats.spiritual_attack)
	_sdef_value.text = str(display_stats.spiritual_defense)

	var unlocked_skills: Array = job.get_unlocked_skills(level)

	for i in skills.size():
		var skill = skills[i]
		var is_skill_locked: bool = false

		if not can_ignore_locked_skills:
			is_skill_locked = not skill in unlocked_skills

		var pill: PanelContainer = skill_pill_packed_scene.instantiate()

		_skills_vbox.add_child(pill)

		pill.setup(skill, can_show_activation_rate, is_skill_locked, job.get_skill_boost(i))

	_add_companion_row(job)

	if is_in_battle and not status_effects.is_empty():
		var status_header := Label.new()
		status_header.text = tr("STATUS_EFFECTS_TAB")
		status_header.add_theme_color_override("font_color", Color(0.56, 0.63, 0.74))
		status_header.add_theme_font_override("font", _skills_header.get_theme_font("font"))
		status_header.add_theme_font_size_override("font_size", 16)

		_skills_vbox.add_child(status_header)

		for status_effect in status_effects:
			var row: HBoxContainer = status_row_packed_scene.instantiate()

			_skills_vbox.add_child(row)

			row.initialize_from_status_effect(status_effect)
			row.get_node("Label").add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))


func on_add_to_tree(data: Object) -> void:
	if data is Job:
		_current_job = data

	if _current_job != null:
		initialize(_current_job, _current_job.level)


func _set_focus() -> void:
	_return_button.grab_focus()


func _on_ReturnButton_pressed() -> void:
	_return_button.disabled = true

	go_back()


# Equipped companion line under the skill list: "Companion: Earth Sword (+80 ATK)"
func _add_companion_row(job: Job) -> void:
	var companion = job.companion

	if companion == null:
		return

	# Show the CURRENT scaled grant (companions ride the hero's growth curve
	# and reach their full listed strength at the level cap).
	var growth: float = pow(float(clampi(job.level, 1, Leveling.MAX_LEVEL)), 0.53) / pow(float(Leveling.MAX_LEVEL), 0.53)
	var bonuses := []

	if companion.health_bonus != 0:
		bonuses.push_back("+%d HP" % int(round(companion.health_bonus * growth)))
	if companion.attack_bonus != 0:
		bonuses.push_back("+%d ATK" % int(round(companion.attack_bonus * growth)))
	if companion.defense_bonus != 0:
		bonuses.push_back("+%d DEF" % int(round(companion.defense_bonus * growth)))
	if companion.spiritual_attack_bonus != 0:
		bonuses.push_back("+%d S.ATK" % int(round(companion.spiritual_attack_bonus * growth)))
	if companion.spiritual_defense_bonus != 0:
		bonuses.push_back("+%d S.DEF" % int(round(companion.spiritual_defense_bonus * growth)))

	var row := Label.new()
	row.text = "%s: %s (%s)" % [tr("COMPANION"), tr(companion.companion_name), ", ".join(bonuses)]
	row.add_theme_color_override("font_color", Color(0.72, 0.86, 0.78))
	row.add_theme_font_override("font", _skills_header.get_theme_font("font"))
	row.add_theme_font_size_override("font_size", 16)

	_skills_vbox.add_child(row)


# ---- Element & EXP display (Terra Battle status screen parity) ----

# Luck (Terra Battle): shown for owned player units, next to the element. Drives
# the end-of-battle luck drops (squad total).
func _update_luck_label(job: Job) -> void:
	var owned: bool = GameData.save_data != null and GameData.save_data.jobs.has(job)

	if _luck_label == null:
		if not owned:
			return

		_luck_label = Label.new()
		_luck_label.add_theme_font_size_override("font_size", 18)
		_luck_label.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42))
		var species_row: Node = _weapon_icon.get_parent()
		species_row.add_child(_luck_label)

	_luck_label.visible = owned

	if owned:
		_luck_label.text = "%s %d" % [tr("LUCK"), job.luck]


func _update_element_label(attribute: int) -> void:
	if _element_label == null:
		_element_label = Label.new()
		_element_label.add_theme_font_size_override("font_size", 18)
		var species_row: Node = _weapon_icon.get_parent()
		species_row.add_child(_element_label)
		# Sit right after the weapon icon.
		species_row.move_child(_element_label, _weapon_icon.get_index() + 1)

	if attribute == Enums.Attribute.NONE:
		_element_label.visible = false
		return

	_element_label.visible = true
	_element_label.text = _element_name(attribute)
	_element_label.add_theme_color_override("font_color", _element_color(attribute))


# Training: convert banked coins into EXP for this hero ("various upgrades",
# per the TB wiki's coin usage). Collection view only — never in battle.
const TRAIN_EXP: int = 500
const TRAIN_COST: int = 400

# Metamorphosis (Awaken): a one-way permanent stat boost, gated by level and paid
# in coins + a rare material.
const AWAKEN_MIN_LEVEL: int = 30
const AWAKEN_COIN_COST: int = 3000
const AWAKEN_MATERIAL_ID: String = "core"
const AWAKEN_MATERIAL_COUNT: int = 1

var _train_button: Button = null
var _companion_button: Button = null
var _awaken_button: Button = null
var _awaken_confirming: bool = false
var _wallet_label: Label = null
var _train_job: Job = null


func _update_train_button(job: Job, is_in_battle: bool) -> void:
	var owned: bool = GameData.save_data != null and GameData.save_data.jobs.has(job)
	var show: bool = (not is_in_battle) and owned

	if _train_button == null:
		if not show:
			return

		var meta: Node = _lv_label.get_parent()

		var row := HBoxContainer.new()
		row.name = "TrainRow"
		row.add_theme_constant_override("separation", 10)
		meta.add_child(row)
		meta.move_child(row, _exp_label.get_index() + 1)

		_train_button = Button.new()
		_train_button.custom_minimum_size = Vector2(0, 40)
		_train_button.add_theme_font_size_override("font_size", 14)
		_train_button.add_theme_stylebox_override("normal", _gold_button_style())
		_train_button.pressed.connect(_on_train_pressed)
		row.add_child(_train_button)

		_wallet_label = Label.new()
		_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wallet_label.add_theme_font_size_override("font_size", 14)
		_wallet_label.add_theme_color_override("font_color", Color(0.86, 0.72, 0.42, 1))
		row.add_child(_wallet_label)

		var companion_row := HBoxContainer.new()
		companion_row.name = "CompanionRow"
		meta.add_child(companion_row)
		meta.move_child(companion_row, row.get_index() + 1)

		_companion_button = Button.new()
		_companion_button.custom_minimum_size = Vector2(0, 40)
		_companion_button.add_theme_font_size_override("font_size", 14)
		_companion_button.add_theme_stylebox_override("normal", _gold_button_style())
		_companion_button.text = tr("COMPANION")
		_companion_button.pressed.connect(_on_companion_pressed)
		companion_row.add_child(_companion_button)

		var awaken_row := HBoxContainer.new()
		awaken_row.name = "AwakenRow"
		meta.add_child(awaken_row)
		meta.move_child(awaken_row, companion_row.get_index() + 1)

		_awaken_button = Button.new()
		_awaken_button.custom_minimum_size = Vector2(0, 40)
		_awaken_button.add_theme_font_size_override("font_size", 14)
		_awaken_button.add_theme_stylebox_override("normal", _gold_button_style())
		_awaken_button.pressed.connect(_on_awaken_pressed)
		awaken_row.add_child(_awaken_button)

	var row_node: Node = _train_button.get_parent()
	row_node.visible = show

	if _companion_button != null:
		_companion_button.get_parent().visible = show

	if _awaken_button != null:
		_awaken_button.get_parent().visible = show

	if not show:
		return

	_train_job = job

	var coins: int = GameData.save_data.coins
	var maxed: bool = job.level >= Leveling.MAX_LEVEL

	_train_button.text = "TRAIN  +%d EXP  (%dc)" % [TRAIN_EXP, TRAIN_COST]
	_train_button.disabled = maxed or not Purchase.can_afford(GameData.save_data, TRAIN_COST)
	_wallet_label.text = "MAX" if maxed else "%dc" % coins


func _on_train_pressed() -> void:
	if _train_job == null or _train_job.level >= Leveling.MAX_LEVEL:
		return

	if Purchase.spend(GameData.save_data, TRAIN_COST):
		_train_job.gain_exp(TRAIN_EXP)
		GameData.save()

		# Re-render this panel with the (possibly leveled-up) job
		initialize(_train_job, _train_job.level)


func _gold_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.185, 0.225, 1)
	style.set_border_width_all(1)
	style.border_color = Color(0.753, 0.627, 0.384, 0.8)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)

	return style


func _on_companion_pressed() -> void:
	if _train_job != null:
		navigate("res://ui/companion_equip_menu.tscn", _train_job)


func _update_awaken_button(job: Job) -> void:
	if _awaken_button == null:
		return

	_awaken_confirming = false

	if job.awakened:
		_awaken_button.text = tr("AWAKENED")
		_awaken_button.disabled = true
		_awaken_button.tooltip_text = ""
		return

	var level_ok: bool = job.level >= AWAKEN_MIN_LEVEL
	var affordable: bool = Purchase.can_afford(GameData.save_data, AWAKEN_COIN_COST, {AWAKEN_MATERIAL_ID: AWAKEN_MATERIAL_COUNT})

	_awaken_button.text = "%s  (LV %d)" % [tr("AWAKEN"), AWAKEN_MIN_LEVEL] if not level_ok else tr("AWAKEN")
	_awaken_button.disabled = not (level_ok and affordable)
	_awaken_button.tooltip_text = "%dc + 1 %s" % [AWAKEN_COIN_COST, tr("ITEM_CORE")]


func _on_awaken_pressed() -> void:
	if _train_job == null or _train_job.awakened or _train_job.level < AWAKEN_MIN_LEVEL:
		return

	# One-way and consumes a rare material, so require a second tap to confirm.
	if not _awaken_confirming:
		_awaken_confirming = true
		_awaken_button.text = tr("AWAKEN_CONFIRM")
		return

	if Purchase.spend(GameData.save_data, AWAKEN_COIN_COST, {AWAKEN_MATERIAL_ID: AWAKEN_MATERIAL_COUNT}):
		_train_job.metamorphose()
		GameData.save()

		initialize(_train_job, _train_job.level)


func _update_exp_label(job: Job, level: int) -> void:
	# EXP progression is a player-unit concept. Hide it for reference views such
	# as the bestiary, which shows enemies (they do not gain EXP).
	var owned: bool = GameData.save_data != null and GameData.save_data.jobs.has(job)

	if not owned:
		if _exp_label != null:
			_exp_label.visible = false

		return

	if _exp_label == null:
		_exp_label = Label.new()
		_exp_label.add_theme_font_size_override("font_size", 15)
		_exp_label.add_theme_color_override("font_color", Color(0.6, 0.67, 0.78))
		var meta: Node = _lv_label.get_parent()
		meta.add_child(_exp_label)
		meta.move_child(_exp_label, _lv_label.get_index() + 1)

	if level >= Leveling.MAX_LEVEL:
		_exp_label.text = "NEXT  MAX"
	else:
		var to_next: int = Leveling.exp_for_level(level + 1) - job.current_exp
		_exp_label.text = "NEXT  %d EXP" % maxi(0, to_next)


func _update_desc_label(job: Job) -> void:
	var text: String = job.description if ("description" in job) else ""

	if _desc_label == null:
		_desc_label = Label.new()
		_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc_label.add_theme_font_size_override("font_size", 14)
		_desc_label.add_theme_color_override("font_color", Color(0.604, 0.64, 0.667))
		var root: Node = _skills_header.get_parent()
		root.add_child(_desc_label)
		# Sit between the header block and the skills section.
		root.move_child(_desc_label, _skills_header.get_index())

	_desc_label.visible = text.strip_edges() != ""
	_desc_label.text = text


func _element_name(attribute: int) -> String:
	match attribute:
		Enums.Attribute.FIRE:
			return "FIRE"
		Enums.Attribute.ICE:
			return "ICE"
		Enums.Attribute.LIGHTNING:
			return "LIGHTNING"
		Enums.Attribute.DARKNESS:
			return "DARK"
		Enums.Attribute.HEALING:
			return "HEAL"
		_:
			return ""


func _element_color(attribute: int) -> Color:
	match attribute:
		Enums.Attribute.FIRE:
			return Color(1.0, 0.45, 0.3)
		Enums.Attribute.ICE:
			return Color(0.5, 0.8, 1.0)
		Enums.Attribute.LIGHTNING:
			return Color(1.0, 0.85, 0.3)
		Enums.Attribute.DARKNESS:
			return Color(0.72, 0.52, 0.95)
		Enums.Attribute.HEALING:
			return Color(0.5, 0.9, 0.6)
		_:
			return Color.WHITE
