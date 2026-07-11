extends Node2D
# Procedural hit impact for basic pincer/counter attacks. The flash sprite and
# spark burst restyle per weapon (sword cut, gun ricochet, spear thrust, staff
# glyph) and the sparks take the attacker's element tint when it has one. Call
# setup() BEFORE add_child so _ready styles the burst for the attack.

@export var float_duration_seconds: float = 0.65

# Preset per Enums.WeaponType: flash texture, tint, scale sweep, spin style,
# and spark count. Unknown weapons keep the classic starburst.
var _presets := {
	Enums.WeaponType.SWORD: {
		"texture": preload("res://assets/vfx/slash_cut.png"),
		"tint": Color(0.95, 0.97, 1.0),
		"scale_start": 0.3, "scale_end": 0.62,
		"spin": "random", "sparks": 12,
	},
	Enums.WeaponType.GUN: {
		"texture": preload("res://assets/vfx/ricochet_star.png"),
		"tint": Color(1.0, 0.93, 0.7),
		"scale_start": 0.2, "scale_end": 0.52,
		"spin": "random", "sparks": 16,
	},
	Enums.WeaponType.SPEAR: {
		"texture": preload("res://assets/vfx/thrust_streak.png"),
		"tint": Color(0.85, 0.94, 1.0),
		"scale_start": 0.26, "scale_end": 0.46,
		"spin": "thrust", "sparks": 8,
	},
	Enums.WeaponType.STAFF: {
		"texture": preload("res://assets/vfx/arcane_glyph.png"),
		"tint": Color(0.88, 0.72, 1.0),
		"scale_start": 0.3, "scale_end": 0.64,
		"spin": "spin", "sparks": 10,
	},
}

var _element_spark_tints := {
	Enums.Attribute.FIRE: Color(1.0, 0.65, 0.3),
	Enums.Attribute.ICE: Color(0.6, 0.88, 1.0),
	Enums.Attribute.LIGHTNING: Color(1.0, 0.95, 0.55),
	Enums.Attribute.DARKNESS: Color(0.8, 0.58, 1.0),
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _weapon_type: int = -1
var _attribute: int = Enums.Attribute.NONE

@onready var _flash: Sprite2D = $Flash
@onready var _sparks: CPUParticles2D = $Sparks


func setup(weapon_type: int, attribute: int = Enums.Attribute.NONE) -> void:
	_weapon_type = weapon_type
	_attribute = attribute


func _ready() -> void:
	_rng.randomize()

	z_index = 8

	var scale_start := 0.2
	var scale_end := 0.55
	var spin := false

	var preset: Dictionary = _presets.get(_weapon_type, {})

	if preset.is_empty():
		_flash.rotation = _rng.randf_range(0.0, TAU)
	else:
		_flash.texture = preset.texture
		_flash.modulate = preset.tint
		scale_start = preset.scale_start
		scale_end = preset.scale_end
		_sparks.amount = preset.sparks

		match preset.spin:
			"thrust":
				# Streak reads as a lunge: near-horizontal, flipped at random.
				_flash.rotation = _rng.randf_range(-0.3, 0.3) \
						+ (0.0 if _rng.randf() < 0.5 else PI)
			"spin":
				spin = true
				_flash.rotation = _rng.randf_range(0.0, TAU)
			_:
				_flash.rotation = _rng.randf_range(0.0, TAU)

	# Elemental attackers color their sparks.
	if _element_spark_tints.has(_attribute):
		_sparks.modulate = _element_spark_tints[_attribute]

	_flash.scale = Vector2(scale_start, scale_start)
	_flash.modulate.a = 1.0

	_sparks.emitting = true

	var tween := create_tween()
	tween.tween_property(_flash, "scale", Vector2(scale_end, scale_end), 0.16) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.18) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)

	if spin:
		var spin_tween := create_tween()
		spin_tween.tween_property(_flash, "rotation", _flash.rotation + 1.4, 0.34) \
				.set_trans(Tween.TRANS_CUBIC) \
				.set_ease(Tween.EASE_OUT)

	# Free after the spark burst has finished
	get_tree().create_timer(0.6).timeout.connect(queue_free)
