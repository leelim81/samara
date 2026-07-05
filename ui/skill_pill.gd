extends PanelContainer
# Terra Battle style skill row: a rounded dark capsule with a skill-type icon,
# the skill name, and a "?" that expands the full details. The detail text is
# built by the existing SkillLabelContainer (reused as a throwaway probe) so the
# wording stays identical everywhere.

@export var skill_label_container_scene: PackedScene

@onready var _icon: TextureRect = $H/Icon
@onready var _name: Label = $H/Body/NameLabel
@onready var _detail: Label = $H/Body/DetailLabel
@onready var _q: Button = $H/QButton


func setup(skill: Skill, can_show_activation_rate: bool, is_locked: bool, boost: float = 0.0) -> void:
	# Probe the existing label builder for the canonical text + icon
	var probe := skill_label_container_scene.instantiate()
	probe.initialize(skill, true, is_locked, can_show_activation_rate)

	var full_text: String = probe.get_node("Label").text
	_icon.texture = probe.get_node("TextureRect").texture

	probe.free()

	var skill_name := tr(skill.skill_name)
	var detail := full_text

	# Strip the leading "<name>: " so the capsule shows name + collapsible detail
	if full_text.begins_with(skill_name):
		detail = full_text.substr(skill_name.length()).strip_edges()

		if detail.begins_with(":"):
			detail = detail.substr(1).strip_edges()

	_name.text = skill_name
	_detail.text = detail
	_detail.visible = false

	_q.pressed.connect(_on_QButton_pressed)

	# Earned Skill Boost (Terra Battle "Skill Up"), shown as a cyan bonus.
	if boost > 0.0 and not is_locked:
		var boost_label := Label.new()
		boost_label.text = "+%d%%" % int(round(boost * 100.0))
		boost_label.add_theme_font_size_override("font_size", 15)
		boost_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		boost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		$H.add_child(boost_label)
		$H.move_child(boost_label, _q.get_index())

	if is_locked:
		modulate = Color(1, 1, 1, 0.45)
		_q.disabled = true


func _on_QButton_pressed() -> void:
	_detail.visible = not _detail.visible
