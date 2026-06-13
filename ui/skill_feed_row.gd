extends PanelContainer
# One row in the shared skill feed: weapon icon + skill name in a compact
# pill. Fades in, holds, fades out, then frees itself. The feed's VBox keeps
# rows from ever overlapping.


const LIFETIME_SECONDS := 1.9
const FADE_IN_SECONDS := 0.16
const FADE_OUT_SECONDS := 0.3

@onready var _icon: TextureRect = $Margin/HBox/Icon
@onready var _label: Label = $Margin/HBox/NameLabel


func setup(skill: Skill) -> void:
	_icon.texture = load(Enums.WEAPON_TYPE_TEXTURES[skill.primary_weapon_type])
	_label.text = tr(skill.skill_name)


func play() -> void:
	modulate.a = 0.0

	# Slide up a touch as it fades in
	var start_offset := 10.0

	pivot_offset = Vector2.ZERO

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)
	tween.tween_interval(LIFETIME_SECONDS)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
