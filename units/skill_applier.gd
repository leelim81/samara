extends Node


const WEAPON_ADVANTAGE: float = 2.0
const WEAPON_DISADVANTAGE: float = 1.0

# Terra Battle damage model:
# physical = 1.395 * power * ATK^1.7 / DEF^0.7
# magical  = 1.5   * power * MATK^1.7 / MDEF^0.7
const PHYSICAL_DAMAGE_MODIFIER: float = 1.395
const STAFF_DAMAGE_MODIFIER: float = 1.5
const ATTACK_EXPONENT: float = 1.7
const DEFENSE_EXPONENT: float = 0.7

# Heal skills restore this multiple of their computed magnitude.
const HEAL_POWER_MULTIPLIER: float = 3.0

# A unit standing on a Powered Point deals/heals this multiple (Terra Battle ×1.5).
const POWERED_POINT_DAMAGE_MULTIPLIER: float = 1.5


@export var target_unit_path: NodePath
@export var status_effect_node2d_path: NodePath

var _random := RandomNumberGenerator.new()

@onready var _status_effect_node2d: Node2D = get_node(status_effect_node2d_path)
@onready var _target_unit: Unit = get_node(target_unit_path)


func _ready() -> void:
	_random.randomize()


# Applies a skill, inflicts/heals damage, adds/removes status effects and stats modifiers
func apply_skill(unit: Unit,
		skill: Skill,
		on_damage_absorbed_callback: Callable,
		status_effects: Array) -> void:
	if (skill.is_attack() or skill.is_healing()) and skill.primary_power > 0:
		var damage := calculate_damage(unit.get_stats(), _target_unit.get_stats(), skill.primary_power, skill.primary_weapon_type, skill.primary_attribute)
		
		var powered_mult: float = POWERED_POINT_DAMAGE_MULTIPLIER if unit.is_on_powered_point else 1.0
		damage = int(damage * powered_mult * _random.randf_range(0.9, 1.1))

		if skill.is_healing():
			damage = -int(damage * HEAL_POWER_MULTIPLIER)
		
		var absorbed_damage = int(skill.absorb_rate * damage)

		if on_damage_absorbed_callback.is_valid():
			on_damage_absorbed_callback.call(absorbed_damage)

		var emphasis: int = _damage_emphasis(skill.primary_weapon_type, skill.primary_attribute, _target_unit.get_stats())

		_target_unit.inflict_damage(damage, emphasis)

		if damage > 0:
			_target_unit.on_attacked()

			# Power Gauge: a player hit an enemy survives charges the gauge (TB).
			if unit.faction == Unit.PLAYER_FACTION and _target_unit.faction == Unit.ENEMY_FACTION and _target_unit.is_alive():
				Events.emit_signal("enemy_survived_player_hit")
	
	var has_modified_stats: bool = false
	
	# If it has status effect, try to apply it
	# Skill can cause damage AND inflict status effect, so it can't be if-else
	if skill.has_status_effects() and _can_inflict_status_effects(skill):
		for status_effect_resource in skill.status_effects:
			var status_effect: StatusEffect = status_effect_resource.duplicate()
			
			if status_effect.is_buff() or _can_apply_status_effect(_target_unit.get_stats(), status_effect):
				has_modified_stats = true
				
				status_effect.initialize(unit.get_stats())
				status_effect.is_equipped = skill.is_equipped()
				
				status_effects.append(status_effect)
				
				print("Applied %s to %s" % [status_effect.status_effect_type, _target_unit.name])
				
				_status_effect_node2d.add(status_effect.status_effect_type, status_effect.effect_scene)
			else:
				print("%s resisted %s" % [name, status_effect.status_effect_type])
	
	if skill.can_cure_status_effects():
		var status_effects_to_remove := []
		
		for status_effect in status_effects:
			if status_effect.is_equipped:
				continue
			
			if status_effect.status_effect_type in skill.cured_status_effects:
				status_effects_to_remove.append(status_effect)
		
		for status_effect in status_effects_to_remove:
			remove_status_effect(status_effects, status_effect)
		
		if not status_effects_to_remove.is_empty():
			has_modified_stats = true
	
	if has_modified_stats:
		_target_unit.recalculate_stats()


func calculate_damage(attacker_stats: Stats,
			defender_stats: Stats,
			power: float,
			weapon_type: int,
			attribute: int) -> int:
	var damage: float = 0

	if weapon_type == Enums.WeaponType.STAFF:
		# Magical attack: spiritual attack vs spiritual defense.
		damage = STAFF_DAMAGE_MODIFIER * power \
				* pow(attacker_stats.spiritual_attack, ATTACK_EXPONENT) \
				/ pow(max(1.0, defender_stats.spiritual_defense), DEFENSE_EXPONENT)
	else:
		# Physical attack: attack vs defense.
		damage = PHYSICAL_DAMAGE_MODIFIER * power \
				* pow(attacker_stats.attack, ATTACK_EXPONENT) \
				/ pow(max(1.0, defender_stats.defense), DEFENSE_EXPONENT)

	# Terra Battle applies BOTH advantage multipliers AFTER the base damage:
	# the Circle of Carnage weapon triangle (1.0 for STAFF or neutral matchups)
	# and the elemental advantage (1.0 for non-elemental attacks). Applying both
	# unconditionally lets an elemental physical weapon benefit from each, as TB does.
	damage *= _get_weapon_type_advantage(weapon_type, defender_stats.weapon_type)
	damage *= _get_attribute_multiplier(defender_stats, attribute, defender_stats.attribute)

	return int(damage)


func inflict(status_effect_type: int, status_effects: Array) -> void:
	var accumulated_damage: int = 0
	
	for status_effect in status_effects:
		if status_effect.status_effect_type == status_effect_type:
			accumulated_damage += status_effect.calculate_damage(_target_unit.get_stats())
			
			status_effect.update()
	
	_target_unit.inflict_damage(accumulated_damage)
	
	var status_effects_to_remove := []
	
	for status_effect in status_effects:
		if status_effect.status_effect_type == status_effect_type and status_effect.is_done():
			assert(not status_effect.is_equipped)
			
			status_effects_to_remove.append(status_effect)
	
	for status_effect in status_effects_to_remove:
		remove_status_effect(status_effects, status_effect)
	
	if not status_effects_to_remove.is_empty():
		_target_unit.recalculate_stats()


func remove_status_effect(status_effects: Array, status_effect: StatusEffect) -> void:
	if status_effect.is_equipped:
		return
	
	var index: int = status_effects.find(status_effect)
	
	if index != -1:
		status_effects.remove_at(index)
		
		_status_effect_node2d.remove(status_effect.status_effect_type)


func _get_weapon_type_advantage(attacker_weapon_type: int, defender_weapon_type: int) -> float:
	if attacker_weapon_type == defender_weapon_type or attacker_weapon_type == Enums.WeaponType.STAFF:
		return 1.0
	
	var disadvantaged_weapon_type = Enums.WEAPON_RELATIONSHIPS.get(attacker_weapon_type)
	
	if disadvantaged_weapon_type == defender_weapon_type:
		return WEAPON_ADVANTAGE
	else:
		return WEAPON_DISADVANTAGE


# Returns the elemental damage multiplier the defender takes from an attack of
# the given attribute. Mirrors _get_weapon_type_advantage:
#   - non-elemental (NONE) or support (HEALING) attacker: 1.0 (no bonus)
#   - opposed pair (Fire<->Ice, Lightning<->Darkness): 2.0 (double damage)
#   - same attribute: 1.0 - same_attribute_resistance (a value >1.0 heals)
#   - otherwise: 1.0
# Damage-number emphasis: 1 = advantaged (weapon/element), 2 = resisted, 0 = normal.
func _damage_emphasis(weapon_type: int, attribute: int, defender_stats: Stats) -> int:
	var multiplier: float = _get_weapon_type_advantage(weapon_type, defender_stats.weapon_type) \
			* _get_attribute_multiplier(defender_stats, attribute, defender_stats.attribute)

	if multiplier > 1.0:
		return 1

	if multiplier < 1.0:
		return 2

	return 0


func _get_attribute_multiplier(defender_stats: Stats, attacker_attribute, defender_attribute) -> float:
	if attacker_attribute == Enums.Attribute.NONE or attacker_attribute == Enums.Attribute.HEALING:
		return 1.0

	if attacker_attribute == defender_attribute:
		return 1.0 - defender_stats.same_attribute_resistance

	var opposed_attribute = Enums.ATTRIBUTE_RELATIONSHIPS.get(attacker_attribute)

	if opposed_attribute != null and opposed_attribute == defender_attribute:
		# Opposed elements deal double damage.
		return WEAPON_ADVANTAGE

	# TODO (P3): consult a per-element resistance table on the defender.
	return 1.0


func _can_inflict_status_effects(skill: Skill) -> bool:
	# Always 'inflict' equipped skills
	if skill.is_equipped():
		return true
	
	return _random.randf() < skill.status_effect_infliction_rate


func _can_apply_status_effect(stats: Stats, status_effect: StatusEffect) -> bool:
	assert(not status_effect.status_effect_type == Enums.StatusEffectType.BUFF)
	assert(not status_effect.status_effect_type == Enums.StatusEffectType.REGENERATE)
	
	var vulnerability: float = stats.get_vulnerability(status_effect.status_effect_type)
	
	return _random.randf() < vulnerability

