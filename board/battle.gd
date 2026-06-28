extends MarginContainer


@export var next_scene: String # (String, FILE, "*.tscn")

@export var chapter_data: Resource 

@export var enemy_phase_container_fade_time_seconds: float = 0.75

@export var view_unit_menu_packed_scene: PackedScene

@export var view_unit_menu_fade_time_seconds: float = 0.5

var _timer: Timer
var _player_turn_count: int = 0
var _total_drag_time_seconds: float = 0

var _is_battle_finished: bool = false

var _progress_tween: Tween
var _view_unit_menu_tween: Tween

@onready var _progress_bar: TextureProgressBar = $CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/TimerRow/MoveTimer
@onready var _your_turn_label: Label = $CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/TimerRow/YourTurnLabel

# Live battle-spoils HUD (built programmatically; see _build_live_hud).
var _wave_label: Label
var _coins_label: Label
var _exp_label: Label
var _ko_label: Label

@onready var _power_segments: Array = [
	$CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/PowerGauge/Seg1,
	$CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/PowerGauge/Seg2,
	$CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/PowerGauge/Seg3,
]

@onready var _squad_icons: Array = [
	$CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/SquadIcons/Icon1,
	$CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/SquadIcons/Icon2,
	$CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/SquadIcons/Icon3,
	$CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/SquadIcons/Icon4,
	$CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/SquadIcons/Icon5,
	$CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/SquadIcons/Icon6,
	$CanvasLayer/MarginContainer/Hud/MainRow/StatusBlock/SquadIcons/Icon7,
]


func _ready() -> void:
	set_process(false)
	
	GameData.load_data()
	
	_build_live_hud()
	_build_pause_menu()
	_bind_squad_icons()

	if not $Board.spoils_changed.is_connected(_on_spoils_changed):
		$Board.spoils_changed.connect(_on_spoils_changed)

	if not $Board.power_changed.is_connected(_on_power_changed):
		$Board.power_changed.connect(_on_power_changed)

	$BattleTheme.play()


func _process(_delta: float) -> void:
	var percentage_left = _progress_bar.max_value * _timer.time_left / _timer.wait_time

	_progress_bar.value = percentage_left

	# Bar turns red as the move timer runs out
	var urgency: float = clampf(percentage_left / _progress_bar.max_value / 0.35, 0.0, 1.0)

	_progress_bar.tint_progress = Color(1.0, 0.38, 0.32).lerp(Color.WHITE, urgency)


func on_instance(data: Object) -> void:
	assert(data is ChapterData)

	chapter_data = data


func _update_turn_count() -> void:
	var label: Label = $CanvasLayer/MarginContainer/Hud/MainRow/TurnBlock/TurnCountLabel

	label.text = "%d" % _player_turn_count

	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.35, 1.35)

	var pop_tween := create_tween()
	pop_tween.tween_property(label, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


## Signals

func _on_Board_drag_timer_started(timer: Timer) -> void:
	_timer = timer
	
	_progress_bar.value = _progress_bar.max_value
	
	set_process(true)


func _on_Board_drag_timer_stopped(time_left_seconds: float) -> void:
	set_process(false)
	
	if _timer != null:
		_total_drag_time_seconds += _timer.wait_time - time_left_seconds
	
	_timer = null


func _on_Board_drag_timer_reset() -> void:
	if _progress_tween != null:
		_progress_tween.kill()

	_progress_tween = create_tween()
	_progress_tween.tween_property(_progress_bar, "value", _progress_bar.max_value, 0.5) \
			.set_trans(Tween.TRANS_LINEAR)
	_progress_tween.parallel().tween_property(_progress_bar, "tint_progress", Color.WHITE, 0.5)


func _on_Board_player_turn_started() -> void:
	_player_turn_count += 1

	_update_turn_count()

	_your_turn_label.visible = true
	_refresh_squad_icon_states()


func _on_Board_victory() -> void:
	if _is_battle_finished:
		return

	_is_battle_finished = true

	# Results screen animates in real time regardless of fast-forward
	Engine.time_scale = 1.0

	$CanvasLayer/VictoryScreen.initialize(_total_drag_time_seconds, _player_turn_count, $Board.get_battle_spoils())

	# Let the last death dissolve finish before the banner drops
	# Give the boss slice-death (~1.4s) time to play out before results
	await get_tree().create_timer(1.5).timeout

	$CanvasLayer/VictoryScreen.show()
	$CanvasLayer/VictoryScreen.focus_default_button()


func _on_Board_defeat() -> void:
	if _is_battle_finished:
		return

	_is_battle_finished = true

	Engine.time_scale = 1.0

	await get_tree().create_timer(0.6).timeout

	$CanvasLayer/DefeatScreen.show()
	$CanvasLayer/DefeatScreen.focus_default_button()

	$BattleTheme.stop()


func _on_DefeatScreen_quit_button_pressed() -> void:
	if Loader.change_scene_to_file("res://ui/pre_battle_menu/stack_based_pre_battle_menu.tscn") != OK:
		printerr("Failed to return to pre-battle menu")


func _on_DefeatScreen_try_again_button_pressed() -> void:
	if Loader.change_scene_to_file(scene_file_path, chapter_data) != OK:
		printerr("Failed to reload scene")


func _on_VictoryScreen_continue_button_pressed() -> void:
	# Award battle EXP to the active squad so levels carry over (persistent leveling).
	$Board.award_exp_to_squad()

	# Mark this chapter cleared and unlock the next one in the story list.
	if chapter_data != null and chapter_data is ChapterData:
		GameData.save_data.clear_chapter_and_unlock_next(chapter_data.title)

	GameData.save()

	if Loader.change_scene_to_file(next_scene, chapter_data) != OK:
		printerr("Failed to change to %s" % next_scene)


func _on_GiveUpButton_pressed() -> void:
	# Route Give Up through the pause menu so it needs confirmation.
	_open_pause_menu()


func _on_PauseButton_pressed() -> void:
	_open_pause_menu()


func _on_DragModeOptionButton_drag_mode_changed(drag_mode: int) -> void:
	$Board.update_drag_mode(drag_mode)


func _on_FastForwardButton_fast_forward_toggled(enabled: bool) -> void:
	$Board.set_fast_forward(enabled)


func _on_Board_enemy_phase_started(current_enemy_phase: int, enemy_phase_count: int) -> void:
	if _your_turn_label != null:
		_your_turn_label.visible = false

	var control: Control = $CanvasLayer/EnemyPhaseCenterContainer
	var banner: Control = $CanvasLayer/EnemyPhaseCenterContainer/Banner

	control.show()

	$CanvasLayer/EnemyPhaseCenterContainer/Banner/Margin/VBox/SubtitleLabel.text = tr("BATTLE").to_upper()
	$CanvasLayer/EnemyPhaseCenterContainer/Banner/Margin/VBox/NumberLabel.text = "%d / %d" % [current_enemy_phase, enemy_phase_count]

	if _wave_label != null:
		_wave_label.text = "%d / %d" % [current_enemy_phase, enemy_phase_count]

	# Fade the layer in and pop the card so it lands cleanly
	var control_tween := create_tween()
	control_tween.tween_property(control, "modulate", Color.WHITE, enemy_phase_container_fade_time_seconds) \
			.from(Color.TRANSPARENT) \
			.set_trans(Tween.TRANS_LINEAR)

	banner.pivot_offset = banner.get_combined_minimum_size() / 2.0
	banner.scale = Vector2(0.85, 0.85)

	var pop_tween := create_tween()
	pop_tween.tween_property(banner, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _on_Board_enemies_appeared() -> void:
	var control: Control = $CanvasLayer/EnemyPhaseCenterContainer

	var control_tween := create_tween()
	control_tween.tween_property(control, "modulate", Color.TRANSPARENT, enemy_phase_container_fade_time_seconds) \
			.set_trans(Tween.TRANS_LINEAR)

	await control_tween.finished

	$CanvasLayer/EnemyPhaseCenterContainer.hide()


func _on_Board_unit_selected_for_view(unit: Unit) -> void:
	if _view_unit_menu_tween != null and _view_unit_menu_tween.is_running():
		return

	var view_unit_menu: Control = view_unit_menu_packed_scene.instantiate()

	$ViewUnitMenuCanvasLayer.add_child(view_unit_menu)

	view_unit_menu.initialize_from_data(unit.get_job(), unit.get_base_stats(), unit.get_stats(), unit.get_level(), unit.get_skills(), unit.get_status_effects(), unit.faction == Unit.PLAYER_FACTION, true, unit.faction == Unit.ENEMY_FACTION)

	var _error = view_unit_menu.connect("back_requested", Callable(self, "_on_ViewUnitMenu_go_back").bind(view_unit_menu))

	view_unit_menu.modulate = Color.TRANSPARENT

	_view_unit_menu_tween = create_tween()
	_view_unit_menu_tween.tween_property(view_unit_menu, "modulate", Color.WHITE, view_unit_menu_fade_time_seconds) \
			.set_trans(Tween.TRANS_SINE)

	$ViewUnitMenuCanvasLayer/SelectUnitAudio.play()


func _on_ViewUnitMenu_go_back(view_unit_menu: Control) -> void:
	_view_unit_menu_tween = create_tween()
	_view_unit_menu_tween.tween_property(view_unit_menu, "modulate", Color.TRANSPARENT, view_unit_menu_fade_time_seconds) \
			.set_trans(Tween.TRANS_SINE)

	await _view_unit_menu_tween.finished

	view_unit_menu.queue_free()


# ---- Live spoils HUD (Terra Battle battle HUD parity) ----

func _build_live_hud() -> void:
	# Terra Battle shows coin / exp / KO counters across the top-center, each as
	# a small icon followed by a number; CountersRow holds them centered.
	var box: HBoxContainer = $CanvasLayer/MarginContainer/Hud/CountersRow
	var icons: Texture2D = load("res://assets/terra/ui/ui_icons.png")

	# 64px atlas cells: coins(64,128) · sparkle/exp(0,128) · skull/KO(192,128).
	# Semantic icon tints (gold / jade / seal-red) make the row readable on the
	# dark bar and tell the three apart at a glance.
	_coins_label = _make_counter(box, icons, Rect2(64, 128, 64, 64), Color(0.86, 0.72, 0.42))
	_exp_label = _make_counter(box, icons, Rect2(0, 128, 64, 64), Color(0.46, 0.8, 0.68))
	_ko_label = _make_counter(box, icons, Rect2(192, 128, 64, 64), Color(0.85, 0.46, 0.4))
	# Wave is shown in the enemy-phase banner; keep a standalone label so the
	# phase code can still set it without cluttering the 3-counter row.
	_wave_label = Label.new()

	_update_live_hud()


func _make_counter(box: HBoxContainer, atlas_tex: Texture2D, region: Rect2, tint: Color) -> Label:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = atlas_tex
	at.region = region
	icon.texture = at
	icon.custom_minimum_size = Vector2(17, 17)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon)

	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95, 1))
	hb.add_child(label)

	box.add_child(hb)
	return label


func _update_live_hud() -> void:
	if _coins_label == null:
		return

	var spoils: Dictionary = $Board.get_battle_spoils()

	_coins_label.text = "%d" % spoils.coins
	_exp_label.text = "%d" % spoils.exp
	_ko_label.text = "%d" % spoils.defeated


func _on_spoils_changed(_exp: int, _coins: int, _defeated: int) -> void:
	_update_live_hud()


# Power Gauge: light whole segments up to the current power level.
func _on_power_changed(filled: float, _max_bars: int) -> void:
	for i in _power_segments.size():
		_power_segments[i].value = clampf((filled - float(i)) * 100.0, 0.0, 100.0)


# ---- Squad status icons (bound to the real squad; dim on KO) ----

func _bind_squad_icons() -> void:
	var save_data = GameData.save_data
	var active: Array = save_data.active_units

	for i in _squad_icons.size():
		var icon: TextureRect = _squad_icons[i]

		if i < active.size():
			var job = save_data.jobs[active[i]]
			icon.texture = job.portrait
			icon.modulate = Color.WHITE
			icon.visible = true
		else:
			icon.visible = false


func _refresh_squad_icon_states() -> void:
	var units: Array = $Board.get_player_units()

	for i in _squad_icons.size():
		if not _squad_icons[i].visible:
			continue

		if i < units.size() and is_instance_valid(units[i]) and units[i].is_alive():
			_squad_icons[i].modulate = Color.WHITE
		else:
			_squad_icons[i].modulate = Color(0.42, 0.42, 0.46, 0.55)


# ---- In-battle pause menu (Resume / Give Up with confirm) ----

var _pause_overlay: Control


func _build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	_pause_overlay = Control.new()
	_pause_overlay.anchor_right = 1.0
	_pause_overlay.anchor_bottom = 1.0
	_pause_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_pause_overlay.hide()
	layer.add_child(_pause_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.09, 0.72)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_pause_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9))
	vbox.add_child(title)

	var resume := _make_pause_button("RESUME")
	resume.pressed.connect(_on_pause_resume)
	vbox.add_child(resume)

	var give_up := _make_pause_button("GIVE UP")
	give_up.pressed.connect(_on_pause_give_up)
	vbox.add_child(give_up)


func _make_pause_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(260, 64)
	button.add_theme_font_size_override("font_size", 22)
	return button


func _open_pause_menu() -> void:
	if _is_battle_finished or _pause_overlay == null:
		return

	_pause_overlay.show()
	get_tree().paused = true


func _on_pause_resume() -> void:
	get_tree().paused = false
	_pause_overlay.hide()


func _on_pause_give_up() -> void:
	get_tree().paused = false
	_pause_overlay.hide()

	_on_Board_defeat()

	$Board.on_give_up()

