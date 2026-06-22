extends Node2D


@onready var label: Label = $Label

@export var heal_color: Color

var _random := RandomNumberGenerator.new()


const EMPHASIS_NORMAL := 0
const EMPHASIS_ADVANTAGE := 1
const EMPHASIS_RESISTED := 2


func play(value: int, emphasis: int = EMPHASIS_NORMAL) -> void:
	if value == 0:
		hide()

		queue_free()

		return

	var peak_scale := 1.0

	if value < 0:
		# Heal
		label.modulate = heal_color
		label.text = "+%d" % abs(value)
	else:
		label.text = str(value)

		# Circle-of-Carnage / elemental advantage hits pop larger and gold;
		# resisted hits are smaller and dim.
		if emphasis == EMPHASIS_ADVANTAGE:
			label.modulate = Color(1.0, 0.84, 0.3)
			peak_scale = 1.4
		elif emphasis == EMPHASIS_RESISTED:
			label.modulate = Color(0.62, 0.68, 0.74)
			peak_scale = 0.82

	_random.randomize()

	# Horizontal jitter so stacked chain hits don't overlap perfectly
	position += Vector2(_random.randf_range(-14.0, 14.0), _random.randf_range(-8.0, 2.0))

	modulate.a = 0.0
	scale = Vector2(0.4, 0.4)

	# Pop in with overshoot, hold briefly, then fade
	var life_tween := create_tween()
	life_tween.tween_property(self, "scale", Vector2(peak_scale, peak_scale), 0.16) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	life_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.07)
	life_tween.tween_interval(0.28)
	life_tween.tween_property(self, "modulate:a", 0.0, 0.22) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
	life_tween.tween_callback(queue_free)

	# Gentle upward drift across the whole lifetime
	var float_tween := create_tween()
	float_tween.tween_property(label, "position:y", label.position.y - 40.0, 0.73) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
