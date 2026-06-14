extends Node2D
# Procedural hit impact (replaces the old Genso cross sprite): a starburst
# flash that snaps open and fades, plus a quick radial spark burst.

@export var float_duration_seconds: float = 0.65

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _flash: Sprite2D = $Flash
@onready var _sparks: CPUParticles2D = $Sparks


func _ready() -> void:
	_rng.randomize()

	z_index = 8

	_flash.rotation = _rng.randf_range(0.0, TAU)
	_flash.scale = Vector2(0.2, 0.2)
	_flash.modulate.a = 1.0

	_sparks.emitting = true

	var tween := create_tween()
	tween.tween_property(_flash, "scale", Vector2(0.55, 0.55), 0.16) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.18) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)

	# Free after the spark burst has finished
	get_tree().create_timer(0.6).timeout.connect(queue_free)
