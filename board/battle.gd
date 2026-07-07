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

@onready var _progress_bar: TextureProgressBar = $CanvasLayer/MarginContainer/Hud/Row2/C1/TimerRow/TimerBar
@onready var _your_turn_label: Label = $CanvasLayer/MarginContainer/Hud/Row2/C1/TimerRow/TimerBar/YourTurnLabel

# Live battle-spoils HUD (static grid labels; see the Row1/Row2 columns).
@onready var _wave_label: Label = $CanvasLayer/MarginContainer/Hud/Row2/C3/WavePair/Value
@onready var _coins_label: Label = $CanvasLayer/MarginContainer/Hud/Row1/C2/CoinPair/Value
@onready var _exp_label: Label = $CanvasLayer/MarginContainer/Hud/Row2/C2/ExpPair/Value
@onready var _ko_label: Label = $CanvasLayer/MarginContainer/Hud/Row1/C3/KoPair/Value

@onready var _power_segments: Array = [
	$CanvasLayer/MarginContainer/Hud/Row1/C1/PGauge/Seg1,
	$CanvasLayer/MarginContainer/Hud/Row1/C1/PGauge/Seg2,
	$CanvasLayer/MarginContainer/Hud/Row1/C1/PGauge/Seg3,
]

func _ready() -> void:
	set_process(false)
	
	GameData.load_data()
	
	_build_live_hud()
	_build_pause_menu()

	# The first enemy_phase_started fires during Board._ready, before this
	# node's @onready labels exist — backfill the wave display.
	_wave_label.text = "%d / %d" % [max(1, $Board._current_enemy_phase), max(1, $Board._enemy_phase_count)]

	# Apply the saved drag mode up front: the HUD OptionButton's initial
	# select() never emits, so without this the saved mode wouldn't take
	# effect until the player re-picked it.
	$Board.update_drag_mode(GameData.save_data.drag_mode)

	if not $Board.spoils_changed.is_connected(_on_spoils_changed):
		$Board.spoils_changed.connect(_on_spoils_changed)

	if not $Board.power_changed.is_connected(_on_power_changed):
		$Board.power_changed.connect(_on_power_changed)

	Events.power_boost_changed.connect(_on_power_boost_changed)

	$BattleTheme.play()


func _process(_delta: float) -> void:
	var percentage_left = _progress_bar.max_value * _timer.time_left / _timer.wait_time

	_progress_bar.value = percentage_left

	# Bar turns red as the move timer runs out
	var urgency: float = clampf(percentage_left / _progress_bar.max_value / 0.35, 0.0, 1.0)

	_progress_bar.tint_progress = Color(1.0, 0.38, 0.32).lerp(Color.WHITE, urgency)


# Cheat / fast-test hotkey: press K to instantly clear every enemy and win the
# current battle.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		$Board.debug_win_battle()

		get_viewport().set_input_as_handled()


func on_instance(data: Object) -> void:
	assert(data is ChapterData)

	chapter_data = data


## Signals

func _on_Board_drag_timer_started(timer: Timer) -> void:
	_timer = timer
	
	_progress_bar.value = _progress_bar.max_value
	_your_turn_label.visible = false
	
	set_process(true)


func _on_Board_drag_timer_stopped(time_left_seconds: float) -> void:
	set_process(false)
	
	if _timer != null:
		_total_drag_time_seconds += _timer.wait_time - time_left_seconds
	
	_timer = null

	# Back to the idle "Your turn" pill: empty the bar, restore the text
	# (the enemy-phase handler hides it again when the turn passes).
	if _progress_tween != null:
		_progress_tween.kill()

	_progress_tween = create_tween()
	_progress_tween.tween_property(_progress_bar, "value", 0.0, 0.3) \
			.set_trans(Tween.TRANS_SINE)
	_progress_tween.parallel().tween_property(_progress_bar, "tint_progress", Color.WHITE, 0.3)

	_your_turn_label.visible = true


func _on_Board_drag_timer_reset() -> void:
	# Fired at the start of each player turn: settle into the idle state —
	# dark pill with the "Your turn" text (TB's bar only fills while a drag
	# timer is actually running).
	if _progress_tween != null:
		_progress_tween.kill()

	_progress_tween = create_tween()
	_progress_tween.tween_property(_progress_bar, "value", 0.0, 0.3) \
			.set_trans(Tween.TRANS_SINE)
	_progress_tween.parallel().tween_property(_progress_bar, "tint_progress", Color.WHITE, 0.3)


func _on_Board_player_turn_started() -> void:
	# Kept for the victory-screen stats; TB's HUD shows no turn counter.
	_player_turn_count += 1

	_your_turn_label.visible = true


var _battle_drops: Dictionary = {}


func _on_Board_victory() -> void:
	if _is_battle_finished:
		return

	_is_battle_finished = true

	# Results screen animates in real time regardless of fast-forward
	Engine.time_scale = 1.0

	_battle_drops = _roll_luck_drops()

	$CanvasLayer/VictoryScreen.initialize(_total_drag_time_seconds, _player_turn_count, $Board.get_battle_spoils(), _preview_squad_gains(), _battle_drops)

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

	# Bank the battle coins into the persistent wallet (spent on training).
	GameData.save_data.coins += $Board.get_battle_spoils().coins

	# Account rank shares the same EXP the squad earns (a separate track).
	GameData.save_data.add_account_exp($Board.get_battle_spoils().exp)

	# Bank materials dropped this battle into the inventory.
	var dropped_materials: Dictionary = $Board.get_battle_spoils().get("materials", {})

	for item_id in dropped_materials:
		GameData.save_data.add_item(item_id, dropped_materials[item_id])

	# Bank the squad's luck drops (bonus coins + materials).
	GameData.save_data.coins += int(_battle_drops.get("coins", 0))

	var luck_materials: Dictionary = _battle_drops.get("materials", {})

	for item_id in luck_materials:
		GameData.save_data.add_item(item_id, luck_materials[item_id])

	# Mark this chapter cleared and unlock the next one in the story list.
	# Story recruitment happens inside clear_chapter_and_unlock_next; remember
	# the roster size so newly joined heroes can be announced.
	var jobs_before: int = GameData.save_data.jobs.size()

	if chapter_data != null and chapter_data is ChapterData and not chapter_data.is_ex:
		GameData.save_data.clear_chapter_and_unlock_next(chapter_data.title)

	GameData.save()

	var joined_jobs: Array = []

	for i in range(jobs_before, GameData.save_data.jobs.size()):
		joined_jobs.push_back(GameData.save_data.jobs[i])

	if joined_jobs.is_empty():
		_go_to_next_scene()
	else:
		_show_new_ally_dialog(joined_jobs)


func _roll_luck_drops() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	return LuckDrops.roll(_squad_luck(), rng)


func _squad_luck() -> int:
	var total: int = 0

	for index in GameData.save_data.active_units:
		if index >= 0 and index < GameData.save_data.jobs.size():
			total += GameData.save_data.jobs[index].luck

	return total


# Preview what award_exp_to_squad WILL grant, per hero, for the results
# screen: [{name, gain, levels_gained}]. Mirrors the board's equal split.
func _preview_squad_gains() -> Array:
	var gains: Array = []
	var save_data = GameData.save_data
	var active: Array = save_data.active_units

	if active.is_empty():
		return gains

	var share: int = int($Board.get_battle_spoils().exp / active.size())

	for index in active:
		if index >= 0 and index < save_data.jobs.size():
			var job = save_data.jobs[index]
			var level_after: int = Leveling.level_for_exp(job.current_exp + share)

			gains.push_back({
				"name": tr(job.job_name),
				"gain": share,
				"levels_gained": level_after - job.level,
			})

	return gains


func _go_to_next_scene() -> void:
	# EX stages skip the story post-battle chain and return straight to the hub.
	var destination: String = next_scene

	if chapter_data is ChapterData and chapter_data.is_ex:
		destination = "res://ui/pre_battle_menu/stack_based_pre_battle_menu.tscn"

	if Loader.change_scene_to_file(destination, chapter_data) != OK:
		printerr("Failed to change to %s" % destination)


# Announce story joins before leaving the battle, so the recruitment drip is
# a visible reward and not a silent roster change. Themed overlay (the stock
# AcceptDialog ignored the game theme).
func _show_new_ally_dialog(joined_jobs: Array) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)

	var overlay := Control.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.theme = load("res://theme.tres")
	layer.add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.85)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.122, 0.141, 0.173, 0.97)
	card.set_border_width_all(1)
	card.border_color = Color(0.753, 0.627, 0.384, 0.55)
	card.set_corner_radius_all(14)
	card.shadow_color = Color(0, 0, 0, 0.35)
	card.shadow_size = 18
	card.content_margin_left = 44.0
	card.content_margin_right = 44.0
	card.content_margin_top = 32.0
	card.content_margin_bottom = 36.0
	panel.add_theme_stylebox_override("panel", card)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "NEW ALLY" if joined_jobs.size() == 1 else "NEW ALLIES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://assets/fonts/CinzelDecorativeBold.tres"))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
	vbox.add_child(title)

	var rule := ColorRect.new()
	rule.color = Color(0.753, 0.627, 0.384, 0.4)
	rule.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(rule)

	var caption := Label.new()
	caption.text = "Joined Outer Heaven"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color(0.604, 0.64, 0.667))
	vbox.add_child(caption)

	for job in joined_jobs:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		vbox.add_child(row)

		var frame := PanelContainer.new()
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.055, 0.065, 0.085, 1)
		frame_style.set_border_width_all(1)
		frame_style.border_color = Color(0.753, 0.627, 0.384, 0.7)
		frame_style.set_corner_radius_all(10)
		frame_style.set_content_margin_all(4)
		frame.add_theme_stylebox_override("panel", frame_style)
		row.add_child(frame)

		var portrait := TextureRect.new()
		portrait.texture = job.portrait
		portrait.custom_minimum_size = Vector2(72, 72)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(portrait)

		var name_label := Label.new()
		name_label.text = tr(job.job_name)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(0.94, 0.95, 0.96))
		row.add_child(name_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	var continue_button := Button.new()
	continue_button.text = "CONTINUE"
	continue_button.custom_minimum_size = Vector2(240, 56)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.add_theme_font_size_override("font_size", 19)

	var primary := StyleBoxFlat.new()
	primary.bg_color = Color(0.16, 0.185, 0.225, 1)
	primary.set_border_width_all(1)
	primary.border_color = Color(0.753, 0.627, 0.384, 0.8)
	primary.set_corner_radius_all(10)
	continue_button.add_theme_stylebox_override("normal", primary)
	continue_button.pressed.connect(_go_to_next_scene)
	vbox.add_child(continue_button)

	continue_button.grab_focus()


func _on_PauseButton_pressed() -> void:
	_open_pause_menu()


func _on_DragModeOptionButton_drag_mode_changed(drag_mode: int) -> void:
	$Board.update_drag_mode(drag_mode)

	# Same setting as the settings-menu toggle: persist it, so switching on the
	# HUD (e.g. moving between mouse and touch play) sticks across battles.
	GameData.save_data.drag_mode = drag_mode
	GameData.save()


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
	# The spoils labels live in the .tscn grid now; only the carnage glyphs
	# are built here.
	_build_carnage_circle()

	_update_live_hud()


# The Circle of Carnage (per the TB wiki): sword > gun > spear > sword,
# one-directional, double damage; staff neutral. TB shows it as three icons
# threaded on a loop — carnage_ring.png draws the arcs and chevrons, and the
# glyphs are overlaid here reading the chain from Enums.WEAPON_RELATIONSHIPS
# so the diagram can never drift from the actual damage rule.
func _build_carnage_circle() -> void:
	var circle: Control = $CanvasLayer/MarginContainer/Hud/Row2/C4/CarnageCircle
	var slot_centers := [42.0, 78.0, 114.0]

	var weapon_type: int = Enums.WeaponType.SWORD

	for i in slot_centers.size():
		var glyph := TextureRect.new()
		glyph.texture = load(Enums.WEAPON_TYPE_TEXTURES[weapon_type])
		glyph.custom_minimum_size = Vector2(22, 22)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.modulate = Color(0.92, 0.93, 0.95, 1)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.position = Vector2(slot_centers[i] - 11.0, 4.0)
		glyph.size = Vector2(22, 22)
		circle.add_child(glyph)

		weapon_type = Enums.WEAPON_RELATIONSHIPS[weapon_type]


func _update_live_hud() -> void:
	if _coins_label == null:
		return

	var spoils: Dictionary = $Board.get_battle_spoils()

	_coins_label.text = "%d" % spoils.coins
	_exp_label.text = "%d" % spoils.exp
	_ko_label.text = "%d" % spoils.defeated


func _on_spoils_changed(_exp: int, _coins: int, _defeated: int) -> void:
	_update_live_hud()


# While the chained-Powered-Point boost is armed (x1.5 + guaranteed skills,
# rest of the player turn), the HUD "P" burns bright so the state reads at
# a glance — TB shows the charge, we should too.
var _boost_pulse: Tween

@onready var _p_label: Label = $CanvasLayer/MarginContainer/Hud/Row1/C1/PGauge/P


func _on_power_boost_changed(active: bool) -> void:
	if _boost_pulse != null:
		_boost_pulse.kill()
		_boost_pulse = null

	if active:
		_boost_pulse = create_tween().set_loops()
		_boost_pulse.tween_property(_p_label, "modulate", Color(2.2, 2.2, 2.0, 1.0), 0.35) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_boost_pulse.tween_property(_p_label, "modulate", Color.WHITE, 0.35) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_p_label.modulate = Color.WHITE


# Power Gauge: light whole segments up to the current power level.
func _on_power_changed(filled: float, _max_bars: int) -> void:
	for i in _power_segments.size():
		_power_segments[i].value = clampf((filled - float(i)) * 100.0, 0.0, 100.0)


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
	# The CanvasLayer breaks theme propagation from the Battle root, so the
	# overlay needs the game theme set explicitly.
	_pause_overlay.theme = load("res://theme.tres")
	_pause_overlay.hide()
	layer.add_child(_pause_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.85)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_pause_overlay.add_child(center)

	var panel := PanelContainer.new()
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.122, 0.141, 0.173, 0.97)
	card.set_border_width_all(1)
	card.border_color = Color(0.753, 0.627, 0.384, 0.55)
	card.set_corner_radius_all(14)
	card.shadow_color = Color(0, 0, 0, 0.35)
	card.shadow_size = 18
	card.content_margin_left = 48.0
	card.content_margin_right = 48.0
	card.content_margin_top = 36.0
	card.content_margin_bottom = 40.0
	panel.add_theme_stylebox_override("panel", card)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://assets/fonts/CinzelDecorativeBold.tres"))
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
	vbox.add_child(title)

	var rule := ColorRect.new()
	rule.color = Color(0.753, 0.627, 0.384, 0.4)
	rule.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(rule)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var resume := _make_pause_button("RESUME", true)
	resume.pressed.connect(_on_pause_resume)
	vbox.add_child(resume)

	var give_up := _make_pause_button("GIVE UP", false)
	give_up.add_theme_color_override("font_color", Color(0.85, 0.48, 0.42))
	give_up.pressed.connect(_on_pause_give_up)
	vbox.add_child(give_up)


func _make_pause_button(label: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(280, 62)
	button.add_theme_font_size_override("font_size", 21)

	if primary:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.185, 0.225, 1)
		style.set_border_width_all(1)
		style.border_color = Color(0.753, 0.627, 0.384, 0.8)
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override("normal", style)

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

