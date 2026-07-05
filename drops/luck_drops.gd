class_name LuckDrops
# End-of-battle luck reward (Terra Battle): the squad's combined Luck rolls bonus
# coins and sometimes bonus materials. Higher squad Luck means more chests and a
# chance at rarer materials. Pure + rng-injected so it is easy to unit-test.

const _MATERIAL_LIST_PATH := "res://items/material_list.tres"


static func luck_tier(squad_luck: int) -> int:
	return clampi(squad_luck / 50, 0, 4)


# Returns { "coins": int, "materials": { id: count }, "chests": int }.
static func roll(squad_luck: int, rng: RandomNumberGenerator) -> Dictionary:
	var tier: int = luck_tier(squad_luck)
	var chests: int = 1 + tier
	var coins: int = 0
	var materials: Dictionary = {}

	var pool: Array = _material_pool()

	for _c in chests:
		coins += 40 + tier * 30 + rng.randi_range(0, 40)

		if rng.randf() < 0.18 + tier * 0.12:
			var item = _pick_material(pool, tier, rng)

			if item != null:
				materials[item.id] = int(materials.get(item.id, 0)) + 1

	return {"coins": coins, "materials": materials, "chests": chests}


static func _material_pool() -> Array:
	var list = load(_MATERIAL_LIST_PATH)

	return list.materials() if list != null else []


# Higher luck tiers unlock rarer materials (rarity up to tier + 1).
static func _pick_material(pool: Array, tier: int, rng: RandomNumberGenerator):
	var eligible := []

	for item in pool:
		if item.rarity <= tier + 1:
			eligible.append(item)

	if eligible.is_empty():
		return null

	return eligible[rng.randi_range(0, eligible.size() - 1)]
