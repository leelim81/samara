extends Node2D
# Terra Battle boss death: the character art is cut into horizontal slices
# that flash, shear apart, and fade — with a hollow toll. Built at runtime
# from the boss's icon texture so it matches whatever art is on the tile.


const STRIP_COUNT := 16
const SLIDE_SECONDS := 0.62
const STAGGER_SECONDS := 0.022
const FLASH_SECONDS := 0.14


func play(texture: Texture2D, center_global: Vector2, display_size: Vector2) -> void:
	if texture == null or display_size.x <= 0.0 or display_size.y <= 0.0:
		queue_free()
		return

	global_position = center_global
	z_index = 6

	$DeathAudio.play()

	var tex_size: Vector2 = texture.get_size()
	var sprite_scale: Vector2 = display_size / tex_size

	var strip_tex_h: float = tex_size.y / STRIP_COUNT
	var strip_disp_h: float = display_size.y / STRIP_COUNT
	var top: float = -display_size.y * 0.5

	for i in STRIP_COUNT:
		var strip := Sprite2D.new()

		strip.texture = texture
		strip.region_enabled = true
		strip.region_rect = Rect2(0, i * strip_tex_h, tex_size.x, strip_tex_h)
		strip.centered = true
		strip.scale = sprite_scale
		strip.position = Vector2(0, top + (i + 0.5) * strip_disp_h)

		add_child(strip)

		_animate_strip(strip, i)

	# Free after the last strip finishes
	var total: float = FLASH_SECONDS + STRIP_COUNT * STAGGER_SECONDS + SLIDE_SECONDS + 0.3

	get_tree().create_timer(total).timeout.connect(queue_free)


func _animate_strip(strip: Sprite2D, index: int) -> void:
	# Alternating shear direction, widening toward the ends, so the art
	# fans apart rather than sliding uniformly
	var direction: float = 1.0 if index % 2 == 0 else -1.0
	var distance: float = direction * (22.0 + float(index % 6) * 10.0)

	var rest_x: float = strip.position.x

	# Bright at the cut moment, then shear out and fade
	strip.modulate = Color(1.7, 1.7, 1.7, 1.0)

	var tween := create_tween()

	tween.tween_interval(index * STAGGER_SECONDS)

	# Quick flash settle
	tween.tween_property(strip, "modulate", Color(1, 1, 1, 1), FLASH_SECONDS)

	# Shear apart while fading out
	tween.tween_property(strip, "position:x", rest_x + distance, SLIDE_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(strip, "modulate:a", 0.0, SLIDE_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
