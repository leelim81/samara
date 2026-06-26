extends Control
# One skill callout: a star bullet + glowing colored name over a soft motion
# streak — no box. Slides in from the left (FF16-style), holds, drifts out.
# Color tells the skill kind. The feed stacks these so they never overlap.

signal expired

const STAR_SIZE := 24.0
const GAP := 8.0
const STREAK_LEFT_PAD := 14.0
const STREAK_RIGHT_EXTRA := 64.0

const SLIDE_DISTANCE := 56.0
const SLIDE_IN_SECONDS := 0.24
const HOLD_SECONDS := 1.7
const FADE_OUT_SECONDS := 0.34

var rest_pos: Vector2
var _y_tween: Tween

@onready var _streak: TextureRect = $Streak
@onready var _star: TextureRect = $Star
@onready var _label: Label = $NameLabel


func setup(skill) -> void:
	_label.text = tr(skill.skill_name)

	var col: Color = _color_for(skill.skill_type)

	_label.add_theme_color_override("font_color", col)
	_star.modulate = col

	var font: Font = _label.get_theme_font("font")
	var font_size: int = _label.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	var row_h: float = max(STAR_SIZE, text_size.y)
	var row_w: float = STAR_SIZE + GAP + text_size.x

	size = Vector2(row_w, row_h)

	_star.position = Vector2(0, (row_h - STAR_SIZE) * 0.5)
	_star.size = Vector2(STAR_SIZE, STAR_SIZE)

	_label.position = Vector2(STAR_SIZE + GAP, 0)
	_label.size = Vector2(text_size.x, row_h)

	var streak_h: float = row_h + 8.0
	_streak.position = Vector2(-STREAK_LEFT_PAD, (row_h - streak_h) * 0.5)
	_streak.size = Vector2(row_w + STREAK_LEFT_PAD + STREAK_RIGHT_EXTRA, streak_h)


func _color_for(skill_type: int) -> Color:
	# Illuminated Scroll palette — warm, distinct, read on the dark streak.
	match skill_type:
		Enums.SkillType.HEAL, Enums.SkillType.CURE_AILMENT:
			return Color(0.58, 0.82, 0.55)  # sage green — restore
		Enums.SkillType.BUFF:
			return Color(0.92, 0.78, 0.46)  # gold — empower
		Enums.SkillType.DEBUFF:
			return Color(0.86, 0.56, 0.55)  # dusty rose — afflict
		_:
			return Color(0.95, 0.9, 0.8)    # warm cream — strike


# Slide in from the left, hold, then drift out and free
func play(rest: Vector2) -> void:
	rest_pos = rest

	position = rest + Vector2(-SLIDE_DISTANCE, 0)
	modulate.a = 0.0

	var tween := create_tween()

	tween.set_parallel(true)
	tween.tween_property(self, "position:x", rest.x, SLIDE_IN_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, SLIDE_IN_SECONDS)

	tween.chain().tween_interval(HOLD_SECONDS)

	tween.chain().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:x", rest.x + 24.0, FADE_OUT_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(_on_done)


func _on_done() -> void:
	emit_signal("expired")

	queue_free()


# Smoothly slide to a new stack height when rows above expire
func move_to_y(y: float) -> void:
	rest_pos.y = y

	if _y_tween != null:
		_y_tween.kill()

	_y_tween = create_tween()
	_y_tween.tween_property(self, "position:y", y, 0.2) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)


func dismiss_now() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
