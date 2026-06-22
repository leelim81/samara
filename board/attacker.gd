class_name Attacker
extends Node2D

signal attack_phase_finished

# Seconds from lunge start to the hit landing (sound, flash, damage)
const LUNGE_IMPACT_DELAY_SECONDS := 0.08

# Seconds after impact before the next unit in the chain attacks
const ATTACK_FOLLOW_THROUGH_SECONDS := 0.22

@export var attack_effect_packed_scene: PackedScene = null

# Array<Attack>
var _attack_queue: Array = []
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()


func start(pincer: Pincer) -> void:
	_attack_queue = _queue_attacks(pincer)

	_filter_attacks(_attack_queue)

	_run_attack_sequence()


func _queue_attacks(pincer: Pincer) -> Array:
	var attack_queue := []
	
	# Pincering unit followed by its chain
	for pincering_unit in pincer.pincering_units:
		_queue_attack(attack_queue, pincer.pincered_units, pincering_unit)
		
		# Only player pincers have chaining
		if pincering_unit.faction == Unit.PLAYER_FACTION:
			_queue_chain_attacks(attack_queue, pincer.chain_families[pincering_unit], pincer.pincered_units, pincering_unit)
	
	return attack_queue


func _queue_attack(queue: Array, targeted_units: Array, attacking_unit: Unit, pincering_unit: Unit = null) -> void:
	var attack: Attack = Attack.new()
	
	attack.targeted_units = targeted_units
	attack.attacking_unit = attacking_unit
	
	if pincering_unit == null:
		attack.pincering_unit = attacking_unit
	else:
		attack.pincering_unit = pincering_unit
	
	queue.push_back(attack)


func _queue_chain_attacks(queue: Array, chains: Array, targeted_units: Array, pincering_unit: Unit) -> void:
	for chain in chains:
		for unit in chain:
			_queue_attack(queue, targeted_units, unit, pincering_unit)


func _filter_attacks(attacks: Array) -> void:
	for attack in attacks:
		var filtered_targeted_units: Array = []
		
		for targeted_unit in attack.targeted_units:
			if not targeted_unit.is_dead():
				filtered_targeted_units.push_back(targeted_unit)
		
		attack.targeted_units = filtered_targeted_units


# Plays the whole pincer attack chain: each attacker lunges at its target,
# the hit lands mid-lunge, and the next chain member follows right after.
func _run_attack_sequence() -> void:
	while not _attack_queue.is_empty():
		var attack: Attack = _attack_queue.pop_front()

		if attack.targeted_units.is_empty():
			continue

		if attack.attacking_unit.is_alive():
			attack.attacking_unit.play_attack_lunge(_get_attack_focus(attack))
			attack.attacking_unit.play_attack_zoom()

		await get_tree().create_timer(LUNGE_IMPACT_DELAY_SECONDS).timeout

		_execute_attack(attack)

		await get_tree().create_timer(ATTACK_FOLLOW_THROUGH_SECONDS).timeout

	call_deferred("emit_signal", "attack_phase_finished")


# Point the lunge at the center of everything this attack hits
func _get_attack_focus(attack: Attack) -> Vector2:
	var focus := Vector2.ZERO

	for targeted_unit in attack.targeted_units:
		focus += targeted_unit.global_position

	return focus / attack.targeted_units.size()


func _execute_attack(attack: Attack) -> void:
	var attacker_stats = attack.pincering_unit.get_stats()

	_play_sound(attacker_stats.weapon_type)

	for targeted_unit in attack.targeted_units:
		var damage: int = targeted_unit.calculate_attack_damage(attacker_stats) * _random.randf_range(0.9, 1.1)

		var attack_effect: Node2D = attack_effect_packed_scene.instantiate()
		add_child(attack_effect)

		attack_effect.position = targeted_unit.get_offset_origin()

		var emphasis: int = _pincer_emphasis(attacker_stats, targeted_unit.get_stats())

		targeted_unit.inflict_damage(damage, emphasis)

		targeted_unit.on_attacked()


# Circle-of-Carnage / elemental advantage on a basic pincer hit (1 = advantage).
func _pincer_emphasis(attacker_stats, defender_stats) -> int:
	var weapon_advantage: bool = Enums.WEAPON_RELATIONSHIPS.get(attacker_stats.weapon_type) == defender_stats.weapon_type
	var element_advantage: bool = attacker_stats.attribute != Enums.Attribute.NONE \
			and Enums.ATTRIBUTE_RELATIONSHIPS.get(attacker_stats.attribute) == defender_stats.attribute

	return 1 if (weapon_advantage or element_advantage) else 0


func _play_sound(weapon_type: int) -> void:
	var audio_stream_player: AudioStreamPlayer = _get_audio_stream_player(weapon_type)
	
	if audio_stream_player.playing:
		$BackupAudio.stream = audio_stream_player.stream
		$BackupAudio.volume_db = audio_stream_player.volume_db
		audio_stream_player = $BackupAudio

	audio_stream_player.play()


func _get_audio_stream_player(weapon_type: int) -> Node:
	match(weapon_type):
		Enums.WeaponType.SWORD:
			return $SwordAudio
		Enums.WeaponType.GUN:
			return $GunAudio
		Enums.WeaponType.SPEAR:
			return $SpearAudio
		_:
			return $StaffAudio
