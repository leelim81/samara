extends Control
# Terra Battle style cut-in: large character art sweeps in over the board when
# units pincer, chain, cast skills, or fall. Faithful to TB, it does NOT black
# out the grid — there is no opaque band. Each character carries a soft local
# glow for contrast on the pale board, and the label sits in a compact pill.
# The art enters PERPENDICULAR to the pincer axis so it stays clear of center:
#   vertical pincer (units up/down) -> characters slide in from left and right
#   horizontal pincer (units side by side) -> from top and bottom
# Requests queue so cut-ins never overlap; combat is never gated on them.


class CutInRequest extends RefCounted:
	var textures: Array
	var text: String
	var allied: bool
	var tint: Color
	var enter_from_sides: bool


const SLIDE_IN_SECONDS := 0.3
const HOLD_SECONDS := 0.8
const FADE_OUT_SECONDS := 0.32

const DRIFT_PIXELS := 22.0

# Glow halo size relative to the character art
const GLOW_SCALE := 1.5

const MAX_QUEUE := 4

var _queue: Array = []
var _is_playing := false

@onready var _content: Control = $Content
@onready var _art_a: TextureRect = $Content/ArtA
@onready var _art_b: TextureRect = $Content/ArtB
@onready var _glow_a: TextureRect = $Content/ArtA/GlowA
@onready var _glow_b: TextureRect = $Content/ArtB/GlowB
@onready var _pill: Panel = $Content/Pill
@onready var _name_label: Label = $Content/Pill/NameLabel


func _ready() -> void:
	# Stay present; fade Content via modulate (toggling root visibility left
	# children non-drawing)
	_content.modulate.a = 0.0

	var events: Node = get_node_or_null("/root/Events")

	if events != null:
		var _error = events.connect("cutin_requested", Callable(self, "_on_cutin_requested"))


func _on_cutin_requested(textures: Array, text: String, allied: bool, tint: Color, enter_from_sides: bool = false) -> void:
	if _queue.size() >= MAX_QUEUE:
		return

	var request := CutInRequest.new()

	request.textures = textures
	request.text = text
	request.allied = allied
	request.tint = tint
	request.enter_from_sides = enter_from_sides

	_queue.push_back(request)

	_play_next()


func _play_next() -> void:
	if _is_playing or _queue.is_empty():
		return

	_is_playing = true

	var request: CutInRequest = _queue.pop_front()

	$WhooshAudio.play()

	_name_label.text = request.text

	_style_pill(request.allied)
	_layout_pill()

	# A vertical pincer (units up/down) sends characters in from the sides;
	# a horizontal pincer sends them from top and bottom
	if request.enter_from_sides:
		_play_horizontal(request)
	else:
		_play_vertical(request)


# Compact pill sized to the label, faction-tinted border, centered on screen
func _style_pill(allied: bool) -> void:
	var style: StyleBoxFlat = _pill.get_theme_stylebox("panel")

	if style != null:
		style.border_color = Color(0.752941, 0.627451, 0.384314, 0.6) if allied \
				else Color(0.85, 0.32, 0.28, 0.7)


func _layout_pill() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var font: Font = _name_label.get_theme_font("font")
	var font_size: int = _name_label.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

	var pill_size := Vector2(text_size.x + 64.0, text_size.y + 28.0)

	_pill.size = pill_size
	_pill.position = (screen - pill_size) * 0.5


# Characters slide in from left and right (used for a vertical pincer)
func _play_horizontal(request: CutInRequest) -> void:
	var screen: Vector2 = get_viewport_rect().size
	var art_size := Vector2(320, 540)
	var art_y: float = (screen.y - art_size.y) * 0.5

	var is_dual: bool = request.textures.size() > 1
	var use_a: bool = is_dual or request.allied
	var use_b: bool = is_dual or not request.allied

	var a_rest := Vector2(-12, art_y)
	var b_rest := Vector2(screen.x - art_size.x + 12, art_y)

	_prepare_art(_art_a, _glow_a, art_size, request, 0, use_a, Vector2(-art_size.x, art_y))
	_prepare_art(_art_b, _glow_b, art_size, request, 1 if is_dual else 0, use_b, Vector2(screen.x, art_y))

	var movers := []

	if use_a:
		movers.append({"art": _art_a, "rest": a_rest, "drift": Vector2(DRIFT_PIXELS, 0)})
	if use_b:
		movers.append({"art": _art_b, "rest": b_rest, "drift": Vector2(-DRIFT_PIXELS, 0)})

	_run_cutin(movers)


# Characters slide in from top and bottom (used for a horizontal pincer)
func _play_vertical(request: CutInRequest) -> void:
	var screen: Vector2 = get_viewport_rect().size
	var art_size := Vector2(380, 430)
	var art_x: float = (screen.x - art_size.x) * 0.5

	var is_dual: bool = request.textures.size() > 1
	var use_a: bool = is_dual or request.allied
	var use_b: bool = is_dual or not request.allied

	var a_rest := Vector2(art_x, 8)
	var b_rest := Vector2(art_x, screen.y - art_size.y - 8)

	_prepare_art(_art_a, _glow_a, art_size, request, 0, use_a, Vector2(art_x, -art_size.y))
	_prepare_art(_art_b, _glow_b, art_size, request, 1 if is_dual else 0, use_b, Vector2(art_x, screen.y))

	var movers := []

	if use_a:
		movers.append({"art": _art_a, "rest": a_rest, "drift": Vector2(0, DRIFT_PIXELS)})
	if use_b:
		movers.append({"art": _art_b, "rest": b_rest, "drift": Vector2(0, -DRIFT_PIXELS)})

	_run_cutin(movers)


func _prepare_art(art: TextureRect, glow: TextureRect, art_size: Vector2, request: CutInRequest, texture_index: int, enabled: bool, start_pos: Vector2) -> void:
	art.visible = enabled

	if not enabled:
		return

	art.size = art_size
	art.pivot_offset = art_size * 0.5
	art.texture = request.textures[min(texture_index, request.textures.size() - 1)]
	art.self_modulate = request.tint
	art.scale = Vector2(1.08, 1.08)
	art.position = start_pos

	# Soft dark halo, larger than the art, centered behind it
	var glow_size: Vector2 = art_size * GLOW_SCALE
	glow.size = glow_size
	glow.position = (art_size - glow_size) * 0.5


# Slide-in (with settle scale) -> hold drift -> fade, fading the whole Content
func _run_cutin(movers: Array) -> void:
	_content.modulate = Color(1, 1, 1, 0)
	_pill.scale = Vector2(0.9, 0.9)
	_pill.pivot_offset = _pill.size * 0.5

	var t := create_tween()

	# Phase 1 — content fades in while each art slides and settles
	t.tween_property(_content, "modulate:a", 1.0, SLIDE_IN_SECONDS * 0.7)

	for mover in movers:
		t.parallel().tween_property(mover.art, "position", mover.rest, SLIDE_IN_SECONDS) \
				.set_trans(Tween.TRANS_CUBIC) \
				.set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(mover.art, "scale", Vector2.ONE, SLIDE_IN_SECONDS + 0.1) \
				.set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)

	# Phase 2 — pill pops in just after the art lands
	t.tween_property(_pill, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)

	# Phase 3 — hold with a slow drift
	for i in movers.size():
		var mover = movers[i]
		var drift_target = mover.rest + mover.drift

		if i == 0:
			t.tween_property(mover.art, "position", drift_target, HOLD_SECONDS).set_trans(Tween.TRANS_LINEAR)
		else:
			t.parallel().tween_property(mover.art, "position", drift_target, HOLD_SECONDS).set_trans(Tween.TRANS_LINEAR)

	# Phase 4 — fade everything out together
	t.tween_property(_content, "modulate:a", 0.0, FADE_OUT_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)

	t.tween_callback(_on_cutin_finished)


func _on_cutin_finished() -> void:
	_is_playing = false

	if not _queue.is_empty():
		_play_next()
