extends Control
# Terra Battle style cut-in: large character art slides across a dark band
# when units use skills, chain together, or fall. Requests queue so cut-ins
# never overlap; combat is never gated on them.


class CutInRequest extends RefCounted:
	var textures: Array
	var text: String
	var from_left: bool
	var tint: Color


const SLIDE_IN_SECONDS := 0.18
const HOLD_SECONDS := 0.34
const FADE_OUT_SECONDS := 0.2

# How far past its resting spot the art keeps drifting while the band holds
const DRIFT_PIXELS := 26.0

const MAX_QUEUE := 4

var _queue: Array = []
var _is_playing := false

@onready var _band: Panel = $Band
@onready var _art_left: TextureRect = $Band/ArtLeft
@onready var _art_right: TextureRect = $Band/ArtRight
@onready var _name_label: Label = $Band/NameLabel


func _ready() -> void:
	hide()

	# Path lookup keeps this working in --script tool runs too, where
	# autoload globals can resolve differently
	var events: Node = get_node_or_null("/root/Events")

	if events != null:
		var _error = events.connect("cutin_requested", Callable(self, "_on_cutin_requested"))


func _on_cutin_requested(textures: Array, text: String, from_left: bool, tint: Color) -> void:
	if _queue.size() >= MAX_QUEUE:
		return

	var request := CutInRequest.new()

	request.textures = textures
	request.text = text
	request.from_left = from_left
	request.tint = tint

	_queue.push_back(request)

	_play_next()


func _play_next() -> void:
	if _is_playing or _queue.is_empty():
		return

	_is_playing = true

	var request: CutInRequest = _queue.pop_front()
	var band_width: float = _band.size.x

	show()

	$WhooshAudio.play()

	# Faction-colored hairlines: gold for allied cut-ins, red for enemies
	var band_style: StyleBoxFlat = _band.get_theme_stylebox("panel")

	if band_style != null:
		if request.from_left:
			band_style.border_color = Color(0.752941, 0.627451, 0.384314, 0.7)
		else:
			band_style.border_color = Color(0.85, 0.32, 0.28, 0.75)

	_name_label.text = request.text

	var is_dual: bool = request.textures.size() > 1

	# Single cut-ins use the side matching the acting faction
	var use_left: bool = is_dual or request.from_left
	var use_right: bool = is_dual or not request.from_left

	_art_left.visible = use_left
	_art_right.visible = use_right

	var left_rest_x := 30.0
	var right_rest_x := band_width - 30.0 - _art_right.size.x

	if use_left:
		_art_left.texture = request.textures[0]
		_art_left.self_modulate = request.tint
		_art_left.position.x = -_art_left.size.x

	if use_right:
		_art_right.texture = request.textures[1] if is_dual else request.textures[0]
		_art_right.self_modulate = request.tint
		_art_right.position.x = band_width

	_band.modulate = Color(1, 1, 1, 0)

	var cutin_tween := create_tween()

	cutin_tween.set_parallel(true)
	cutin_tween.tween_property(_band, "modulate:a", 1.0, SLIDE_IN_SECONDS)

	if use_left:
		cutin_tween.tween_property(_art_left, "position:x", left_rest_x, SLIDE_IN_SECONDS) \
				.set_trans(Tween.TRANS_CUBIC) \
				.set_ease(Tween.EASE_OUT)

	if use_right:
		cutin_tween.tween_property(_art_right, "position:x", right_rest_x, SLIDE_IN_SECONDS) \
				.set_trans(Tween.TRANS_CUBIC) \
				.set_ease(Tween.EASE_OUT)

	# Slow drift during the hold keeps the band feeling alive
	cutin_tween.chain().set_parallel(true)

	if use_left:
		cutin_tween.tween_property(_art_left, "position:x", left_rest_x + DRIFT_PIXELS, HOLD_SECONDS) \
				.set_trans(Tween.TRANS_LINEAR)

	if use_right:
		cutin_tween.tween_property(_art_right, "position:x", right_rest_x - DRIFT_PIXELS, HOLD_SECONDS) \
				.set_trans(Tween.TRANS_LINEAR)

	cutin_tween.chain().tween_property(_band, "modulate:a", 0.0, FADE_OUT_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)

	cutin_tween.chain().tween_callback(_on_cutin_finished)


func _on_cutin_finished() -> void:
	_is_playing = false

	if _queue.is_empty():
		hide()
	else:
		_play_next()
