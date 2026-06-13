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

@onready var _progress_bar: TextureProgressBar = $CanvasLayer/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer2/TextureProgressBar


func _ready() -> void:
	set_process(false)
	
	GameData.load_data()
	
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
	var label: Label = $CanvasLayer/MarginContainer/HBoxContainer/VBoxContainer2/TurnCountLabel

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


func _on_Board_victory() -> void:
	if _is_battle_finished:
		return

	_is_battle_finished = true

	# Results screen animates in real time regardless of fast-forward
	Engine.time_scale = 1.0

	$CanvasLayer/VictoryScreen.initialize(_total_drag_time_seconds, _player_turn_count, $Board.get_battle_spoils())

	# Let the last death dissolve finish before the banner drops
	await get_tree().create_timer(0.8).timeout

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
	if Loader.change_scene_to_file(next_scene, chapter_data) != OK:
		printerr("Failed to change to %s" % next_scene)


func _on_GiveUpButton_pressed() -> void:
	_on_Board_defeat()
	
	$Board.on_give_up()


func _on_DragModeOptionButton_drag_mode_changed(drag_mode: int) -> void:
	$Board.update_drag_mode(drag_mode)


func _on_FastForwardButton_fast_forward_toggled(enabled: bool) -> void:
	$Board.set_fast_forward(enabled)


func _on_Board_enemy_phase_started(current_enemy_phase: int, enemy_phase_count: int) -> void:
	var control: Control = $CanvasLayer/EnemyPhaseCenterContainer

	control.show()

	var control_tween := create_tween()
	control_tween.tween_property(control, "modulate", Color.WHITE, enemy_phase_container_fade_time_seconds) \
			.from(Color.TRANSPARENT) \
			.set_trans(Tween.TRANS_LINEAR)

	$CanvasLayer/EnemyPhaseCenterContainer/NinePatchRect/Label.text = "%s %d/%d" % [tr("BATTLE"), current_enemy_phase, enemy_phase_count]


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

