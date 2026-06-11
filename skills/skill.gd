extends Resource

class_name Skill

# Localizable string
@export var skill_name: String = ""
@export var skill_type = Enums.SkillType.ATTACK # (Enums.SkillType)

@export var area_of_effect = Enums.AreaOfEffect.NONE # (Enums.AreaOfEffect)
@export var area_of_effect_size: int = 1 # (int, 1, 10, 1)
@export var activation_rate: float = 0.3 # (float, 0, 1, 0.1)

# True if the skill pushes away affected enemies
@export var is_pusher: bool = false

# Primary effect
@export var primary_power: float = 1 # (float, 0, 3, 0.5)
@export var primary_weapon_type: int = Enums.WeaponType.SWORD # (Enums.WeaponType)

# Primary attribute, only used if weapon type is staff (elemental / magic)
@export var primary_attribute: int = Enums.Attribute.NONE # (Enums.Attribute)

# Note: Unused
@export var secondary_power: float = 0.0 # (float, 0, 3, 0.5)
@export var secondary_weapon_type: int = Enums.WeaponType.GUN # (Enums.WeaponType)
@export var secondary_attribute: int = Enums.Attribute.NONE # (Enums.Attribute)

# If >0, can absorb damage from primary attack, if attack deals damage >0
@export var absorb_rate: float = 0 # (float, 0, 1, 0.1)

# Max HP healed. Also applies to absorbed HP
@export var max_heal: int = 700 # (int, 0, 9000, 100)

# Status effects that this skill applies on allies or
# inflicts on the enemy
# Array<StatusEffect>
@export var status_effects: Array = [] # (Array, Resource)

# Not applied to buffs.
@export var status_effect_infliction_rate: float = 0.3 # (float, 0, 1, 0.1)

# Status effects that this skill removes or cures
@export var cured_status_effects: Array = [] # (Array, Enums.StatusEffectType)

@export var effect_scene: PackedScene = null

# Delayed skills are charged in one turn and activated in the next turn.
# Used only by enemies
@export var is_delayed: bool = false

# Unit or item that this scene summons
@export var summoned_scene: String = "" # (String, FILE, "*.tscn")

# True if this is a escape skill. Will remove unit(s) from play
@export var is_escape: bool = false


func is_physical() -> bool:
	return primary_weapon_type != Enums.WeaponType.STAFF


func is_attack() -> bool:
	return skill_type == Enums.SkillType.ATTACK


func is_healing() -> bool:
	return skill_type == Enums.SkillType.HEAL


func is_buff() -> bool:
	return skill_type == Enums.SkillType.BUFF


func has_summon() -> bool:
	return not summoned_scene.is_empty()


func has_status_effects() -> bool:
	return not status_effects.is_empty()


func can_cure_status_effects() -> bool:
	return not cured_status_effects.is_empty()


func is_enemy_targeted() -> bool:
	return is_attack() or skill_type == Enums.SkillType.DEBUFF or skill_type == Enums.SkillType.COUNTER


func is_targeted_individually() -> bool:
	return area_of_effect in Enums.AREAS_OF_EFFECT_WITH_INDIVIDUAL_TARGETING


func is_equipped() -> bool:
	return area_of_effect == Enums.AreaOfEffect.EQUIP
