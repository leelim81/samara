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


func setup(skill: Skill, can_show_activation_rate: bool, is_locked: bool) -> void:
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

	if is_locked:
		modulate = Color(1, 1, 1, 0.45)
		_q.disabled = true


func _on_QButton_pressed() -> void:
	_detail.visible = not _detail.visible
