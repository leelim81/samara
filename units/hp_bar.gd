extends TextureProgressBar


const DAMAGE_FLASH := Color(1.9, 0.55, 0.55)
const HEAL_FLASH := Color(0.6, 1.9, 0.6)

var _tween: Tween
var _flash_tween: Tween


func _on_Job_health_changed(current_health: int, max_health: int) -> void:
	var next_value: int = int(max_value * current_health / max_health)

	if next_value == int(value):
		return

	_flash(DAMAGE_FLASH if next_value < value else HEAL_FLASH)

	if _tween != null:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "value", next_value, 0.35) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)


# Brief color pulse so HP changes read even on the thin sliver
func _flash(flash_color: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()

	self_modulate = flash_color

	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "self_modulate", Color.WHITE, 0.45) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
