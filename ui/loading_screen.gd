extends CanvasLayer


const FADE_IN_ANIMATION_NAME := "Fade in"
const FADE_OUT_ANIMATION_NAME := "Fade out"

signal fade_in_finished()
signal fade_out_finished()

@onready var animation_player := $AnimationPlayer


func play_loading_animation() -> void:
	animation_player.play(FADE_IN_ANIMATION_NAME)


func fade_out() -> void:
	animation_player.play(FADE_OUT_ANIMATION_NAME)


# Progress is a value between 0 and 1
func update_progress(_progress: float) -> void:
	pass


func _on_AnimationPlayer_animation_finished(animation_name: String) -> void:
	match(animation_name):
		FADE_IN_ANIMATION_NAME:
			emit_signal("fade_in_finished")
			
		FADE_OUT_ANIMATION_NAME:
			emit_signal("fade_out_finished")
