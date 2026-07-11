class_name Attacker
extends Node2D

signal attack_phase_finished
signal counter_phase_finished

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

	_run_attack_sequence("attack_phase_finished")


# Counter phase (Terra Battle): surviving pincered units with a COUNTER skill
# strike back at the two pincering units. "Enemy counter" runs after each
# player pincer resolves; "Player counter" runs after each enemy pincer.
func start_counters(pincer: Pincer) -> void:
	_attack_queue = _queue_counters(pincer)

	_filter_attacks(_attack_queue)

	_run_attack_sequence("counter_phase_finished")


func _queue_counters(pincer: Pincer) -> Array:
	var queue := []

	for pincered_unit in pincer.pincered_units:
		if pincered_unit.is_dead() or not pincered_unit.can_act():
			continue

		var counter_skill: Skill = pincered_unit.get_counter_skill()

		if counter_skill == null:
			continue

		# Same roll convention as unit.activate_skills, so Demoralize's -1
		# skill_activation_rate_modifier disables counters too
		var threshold: float = counter_skill.activation_rate \
				+ pincered_unit.get_stats().skill_activation_rate_modifier

		if _random.randf() >= threshold:
			continue

		var attack: Attack = Attack.new()

		attack.attacking_unit = pincered_unit
		attack.pincering_unit = pincered_unit
		attack.counter_skill = counter_skill
		attack.targeted_units = pincer.pincering_units.duplicate()

		queue.push_back(attack)

	return queue


# Terra Battle attack order: both pincering units first, then the chained
# units, interleaved level by level (first character of each direction of the
# first pincering unit, then of the second, then the second characters, ...).
func _queue_attacks(pincer: Pincer) -> Array:
	var attack_queue := []

	for pincering_unit in pincer.pincering_units:
		_queue_attack(attack_queue, pincer.pincered_units, pincering_unit)

	# Only player pincers have chaining
	if pincer.pincering_units.front().faction == Unit.PLAYER_FACTION:
		var level: int = 0
		var found_chain_level: bool = true

		while found_chain_level:
			found_chain_level = false

			for pincering_unit in pincer.pincering_units:
				var chains: Array = pincer.chain_families[pincering_unit]

				if level < chains.size():
					found_chain_level = true

					for unit in chains[level]:
						_queue_attack(attack_queue, pincer.pincered_units, unit, pincering_unit)

			level += 1

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


func _filter_attacks(attacks: Array) -> void:
	for attack in attacks:
		var filtered_targeted_units: Array = []
		
		for targeted_unit in attack.targeted_units:
			if not targeted_unit.is_dead():
				filtered_targeted_units.push_back(targeted_unit)
		
		attack.targeted_units = filtered_targeted_units


# Plays the whole pincer attack chain: each attacker lunges at its target,
# the hit lands mid-lunge, and the next chain member follows right after.
func _run_attack_sequence(finish_signal: String) -> void:
	while not _attack_queue.is_empty():
		var attack: Attack = _attack_queue.pop_front()

		if attack.targeted_units.is_empty():
			continue

		# Counterattackers can be killed by an earlier counter resolving first
		if attack.counter_skill != null and attack.attacking_unit.is_dead():
			continue

		if attack.attacking_unit.is_alive():
			attack.attacking_unit.play_attack_lunge(_get_attack_focus(attack))
			attack.attacking_unit.play_attack_zoom()

		await get_tree().create_timer(LUNGE_IMPACT_DELAY_SECONDS).timeout

		_execute_attack(attack)

		await get_tree().create_timer(ATTACK_FOLLOW_THROUGH_SECONDS).timeout

	call_deferred("emit_signal", finish_signal)


# Point the lunge at the center of everything this attack hits
func _get_attack_focus(attack: Attack) -> Vector2:
	var focus := Vector2.ZERO

	for targeted_unit in attack.targeted_units:
		focus += targeted_unit.global_position

	return focus / attack.targeted_units.size()


func _execute_attack(attack: Attack) -> void:
	# Each attacker hits with its OWN stats — chained units deal damage with
	# their own ATK, not the pincering unit's (Terra Battle rule)
	var attacker_stats = attack.attacking_unit.get_stats()

	_play_sound(attacker_stats.weapon_type)

	# Chained Powered Point: player damage is boosted x1.5 for the rest of the
	# turn. Enemy hits (e.g. enemy counters during the player turn) never
	# benefit from the player's boost.
	var powered_mult: float = 1.5 if (Events.power_boost_active and attack.attacking_unit.faction == Unit.PLAYER_FACTION) else 1.0

	for targeted_unit in attack.targeted_units:
		var damage: int

		if attack.counter_skill != null:
			# Counterattack: power/weapon/attribute come from the COUNTER skill
			damage = targeted_unit.calculate_damage(attacker_stats,
					targeted_unit.get_stats(),
					attack.counter_skill.primary_power,
					attack.counter_skill.primary_weapon_type,
					attack.counter_skill.primary_attribute) * powered_mult * _random.randf_range(0.9, 1.1)
		else:
			# Terra Battle: chained units strike with their own stats but the
			# PINCERING unit's weapon type decides the Circle of Carnage bonus.
			var advantage_weapon_type: int = attack.pincering_unit.get_stats().weapon_type

			damage = targeted_unit.calculate_attack_damage(attacker_stats, advantage_weapon_type) * powered_mult * _random.randf_range(0.9, 1.1)

		var attack_effect: Node2D = attack_effect_packed_scene.instantiate()

		# Style the impact for this attack: per-weapon flash, element sparks.
		if attack_effect.has_method("setup"):
			if attack.counter_skill != null:
				attack_effect.setup(attack.counter_skill.primary_weapon_type,
						attack.counter_skill.primary_attribute)
			else:
				attack_effect.setup(attacker_stats.weapon_type, attacker_stats.attribute)

		add_child(attack_effect)

		attack_effect.position = targeted_unit.get_offset_origin()

		var emphasis: int
		if attack.counter_skill != null:
			emphasis = _pincer_emphasis(attacker_stats, targeted_unit.get_stats())
		else:
			emphasis = _pincer_emphasis(attacker_stats, targeted_unit.get_stats(),
					attack.pincering_unit.get_stats().weapon_type)

		targeted_unit.inflict_damage(damage, emphasis)

		targeted_unit.on_attacked()

		# Every damaging hit on an enemy that survives it charges the Power
		# Gauge — basic pincer and chain attacks included (Terra Battle rule)
		if damage > 0 and attack.attacking_unit.faction == Unit.PLAYER_FACTION \
				and targeted_unit.faction == Unit.ENEMY_FACTION and targeted_unit.is_alive():
			Events.emit_signal("enemy_survived_player_hit")


# Circle-of-Carnage / elemental advantage on a basic pincer hit (1 = advantage).
# The weapon half uses the PINCERING unit's weapon type, matching the damage
# math for chained units.
func _pincer_emphasis(attacker_stats, defender_stats, advantage_weapon_type: int = -1) -> int:
	var weapon_type: int = advantage_weapon_type if advantage_weapon_type >= 0 else attacker_stats.weapon_type
	var weapon_advantage: bool = Enums.WEAPON_RELATIONSHIPS.get(weapon_type) == defender_stats.weapon_type
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
