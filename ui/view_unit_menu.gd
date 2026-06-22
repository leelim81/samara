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

# Created lazily and reused across initialize() calls.
var _element_label: Label = null
var _exp_label: Label = null


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

	_species_label.text = base_stats.unit_type.capitalize()
	_weapon_icon.texture = load(Enums.WEAPON_TYPE_TEXTURES[base_stats.weapon_type])

	_lv_label.text = "LV %d" % level

	_update_element_label(base_stats.attribute)
	_update_exp_label(job, level)

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

	for skill in skills:
		var is_skill_locked: bool = false

		if not can_ignore_locked_skills:
			is_skill_locked = not skill in unlocked_skills

		var pill: PanelContainer = skill_pill_packed_scene.instantiate()

		_skills_vbox.add_child(pill)

		pill.setup(skill, can_show_activation_rate, is_skill_locked)

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
	var job: Job = data as Job

	initialize(job, job.level)


func _set_focus() -> void:
	_return_button.grab_focus()


func _on_ReturnButton_pressed() -> void:
	_return_button.disabled = true

	go_back()


# ---- Element & EXP display (Terra Battle status screen parity) ----

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


func _update_exp_label(job: Job, level: int) -> void:
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
