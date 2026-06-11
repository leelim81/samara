extends AudioStreamPlayer


@export var fade_time_seconds: float = 0.9

var _fade_tween: Tween


func _ready() -> void:
	if Loader.connect("scene_changed", Callable(self, "_on_Loader_scene_changed")) != OK:
		printerr("Failed to connect to Loader signal")


func _on_Loader_scene_changed() -> void:
	if _fade_tween != null and _fade_tween.is_running():
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "volume_db", -80.0, fade_time_seconds) \
			.set_trans(Tween.TRANS_LINEAR)
