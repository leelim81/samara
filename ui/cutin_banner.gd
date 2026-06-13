extends Control
# Terra Battle style cut-in: large character art sweeps across a dark band
# when units pincer, chain, cast skills, or fall. The band runs PERPENDICULAR
# to the pincer axis so it never covers the units that formed it:
#   vertical pincer (units stacked up/down) -> horizontal band, art from L/R
#   horizontal pincer (units side by side)  -> vertical band, art from top/bottom
# Requests queue so cut-ins never overlap; combat is never gated on them.


class CutInRequest extends RefCounted:
	var textures: Array
	var text: String
	var allied: bool
	var tint: Color
	var vertical_band: bool


# Slower, more readable cadence than a quick flash
const SLIDE_IN_SECONDS := 0.3
const HOLD_SECONDS := 0.8
const FADE_OUT_SECONDS := 0.32

# Slow drift across the hold keeps the frozen art feeling alive
const DRIFT_PIXELS := 24.0

# Band thickness along its short axis
const HORIZONTAL_BAND_HEIGHT := 224.0
const VERTICAL_BAND_WIDTH := 312.0

const MAX_QUEUE := 4

var _queue: Array = []
var _is_playing := false

@onready var _band: Panel = $Band
@onready var _art_a: TextureRect = $Band/ArtA
@onready var _art_b: TextureRect = $Band/ArtB
@onready var _name_label: Label = $NameLabel


func _ready() -> void:
	# The root stays present; the band and label are transparent when idle.
	# (Toggling root visibility between cut-ins left the band non-drawing.)
	_band.modulate.a = 0.0
	_name_label.modulate.a = 0.0

	# Path lookup keeps this working in --script tool runs too, where
	# autoload globals can resolve differently
	var events: Node = get_node_or_null("/root/Events")

	if events != null:
		var _error = events.connect("cutin_requested", Callable(self, "_on_cutin_requested"))


func _on_cutin_requested(textures: Array, text: String, allied: bool, tint: Color, vertical_band: bool = false) -> void:
	if _queue.size() >= MAX_QUEUE:
		return

	var request := CutInRequest.new()

	request.textures = textures
	request.text = text
	request.allied = allied
	request.tint = tint
	request.vertical_band = vertical_band

	_queue.push_back(request)

	_play_next()


func _play_next() -> void:
	if _is_playing or _queue.is_empty():
		return

	_is_playing = true

	var request: CutInRequest = _queue.pop_front()

	$WhooshAudio.play()

	_style_band(request.allied)

	_name_label.text = request.text

	if request.vertical_band:
		_play_vertical(request)
	else:
		_play_horizontal(request)


# Faction-colored hairlines: gold for allied cut-ins, red for enemies
func _style_band(allied: bool) -> void:
	var band_style: StyleBoxFlat = _band.get_theme_stylebox("panel")

	if band_style != null:
		band_style.border_color = Color(0.752941, 0.627451, 0.384314, 0.7) if allied \
				else Color(0.85, 0.32, 0.28, 0.78)


# Wide band centered vertically; art slides in from left and right
func _play_horizontal(request: CutInRequest) -> void:
	var screen: Vector2 = get_viewport_rect().size

	var band_top: float = (screen.y - HORIZONTAL_BAND_HEIGHT) * 0.5

	_band.position = Vector2(0, band_top)
	_band.size = Vector2(screen.x, HORIZONTAL_BAND_HEIGHT)

	_name_label.position = Vector2(0, band_top)
	_name_label.size = Vector2(screen.x, HORIZONTAL_BAND_HEIGHT)

	# Portrait art taller than the slot, biased up so the face frames in the
	# band and the legs crop below (a face-forward cut-in)
	var art_size := Vector2(330, HORIZONTAL_BAND_HEIGHT + 150)
	var art_y: float = -art_size.y * 0.10

	var is_dual: bool = request.textures.size() > 1

	var a_rest := Vector2(8, art_y)
	var b_rest := Vector2(screen.x - art_size.x - 8, art_y)

	_setup_art(_art_a, art_size, request, 0, true)
	_setup_art(_art_b, art_size, request, 1 if is_dual else 0, is_dual or not request.allied)

	# A single cut-in shows one portrait on the acting faction's side
	var use_a: bool = is_dual or request.allied
	var use_b: bool = is_dual or not request.allied

	_art_a.visible = use_a
	_art_b.visible = use_b

	_art_a.position = Vector2(-art_size.x, art_y)
	_art_b.position = Vector2(screen.x, art_y)

	var movers := []

	if use_a:
		movers.append({"art": _art_a, "rest": a_rest, "drift": Vector2(DRIFT_PIXELS, 0)})
	if use_b:
		movers.append({"art": _art_b, "rest": b_rest, "drift": Vector2(-DRIFT_PIXELS, 0)})

	_run_cutin(movers)


# Tall band centered horizontally; art slides in from top and bottom
func _play_vertical(request: CutInRequest) -> void:
	var screen: Vector2 = get_viewport_rect().size

	var band_left: float = (screen.x - VERTICAL_BAND_WIDTH) * 0.5

	_band.position = Vector2(band_left, 0)
	_band.size = Vector2(VERTICAL_BAND_WIDTH, screen.y)

	_name_label.position = Vector2(band_left, (screen.y - 80.0) * 0.5)
	_name_label.size = Vector2(VERTICAL_BAND_WIDTH, 80.0)

	var art_size := Vector2(VERTICAL_BAND_WIDTH + 60, 430)
	var art_x: float = (VERTICAL_BAND_WIDTH - art_size.x) * 0.5

	var is_dual: bool = request.textures.size() > 1

	var a_rest := Vector2(art_x, 20)
	var b_rest := Vector2(art_x, screen.y - art_size.y - 20)

	_setup_art(_art_a, art_size, request, 0, true)
	_setup_art(_art_b, art_size, request, 1 if is_dual else 0, is_dual or not request.allied)

	var use_a: bool = is_dual or request.allied
	var use_b: bool = is_dual or not request.allied

	_art_a.visible = use_a
	_art_b.visible = use_b

	_art_a.position = Vector2(art_x, -art_size.y)
	_art_b.position = Vector2(art_x, screen.y)

	var movers := []

	if use_a:
		movers.append({"art": _art_a, "rest": a_rest, "drift": Vector2(0, DRIFT_PIXELS)})
	if use_b:
		movers.append({"art": _art_b, "rest": b_rest, "drift": Vector2(0, -DRIFT_PIXELS)})

	_run_cutin(movers)


func _setup_art(art: TextureRect, art_size: Vector2, request: CutInRequest, texture_index: int, enabled: bool) -> void:
	if not enabled:
		return

	art.size = art_size
	art.pivot_offset = art_size * 0.5
	art.texture = request.textures[min(texture_index, request.textures.size() - 1)]
	art.self_modulate = request.tint
	art.scale = Vector2(1.08, 1.08)


# Shared slide-in / hold-drift / fade-out for the given movers (one per used
# art). First tween of each phase is sequential; siblings use parallel().
func _run_cutin(movers: Array) -> void:
	_band.modulate = Color(1, 1, 1, 0)
	_name_label.modulate = Color(1, 1, 1, 0)

	var t := create_tween()

	# Phase 1 — band fades in while each art slides and settles its punch scale
	t.tween_property(_band, "modulate:a", 1.0, SLIDE_IN_SECONDS * 0.7)

	for mover in movers:
		t.parallel().tween_property(mover.art, "position", mover.rest, SLIDE_IN_SECONDS) \
				.set_trans(Tween.TRANS_CUBIC) \
				.set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(mover.art, "scale", Vector2.ONE, SLIDE_IN_SECONDS + 0.1) \
				.set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)

	# Phase 2 — name reads in just after the art lands
	t.tween_property(_name_label, "modulate:a", 1.0, 0.16)

	# Phase 3 — hold with a slow drift
	for i in movers.size():
		var mover = movers[i]
		var drift_target = mover.rest + mover.drift

		if i == 0:
			t.tween_property(mover.art, "position", drift_target, HOLD_SECONDS).set_trans(Tween.TRANS_LINEAR)
		else:
			t.parallel().tween_property(mover.art, "position", drift_target, HOLD_SECONDS).set_trans(Tween.TRANS_LINEAR)

	# Phase 4 — band and name fade out together
	t.tween_property(_band, "modulate:a", 0.0, FADE_OUT_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_name_label, "modulate:a", 0.0, FADE_OUT_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)

	t.tween_callback(_on_cutin_finished)


func _on_cutin_finished() -> void:
	_is_playing = false

	if not _queue.is_empty():
		_play_next()
