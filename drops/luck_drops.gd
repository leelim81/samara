class_name LuckDrops
# End-of-battle luck chests, following the Terra Battle wiki thresholds:
#   - the A chest is guaranteed with an average Luck of at least 40,
#   - the B chest is guaranteed with an average Luck of at least 85,
#   - at 100 average Luck the C chest drops 50% of the time and the D chest 25%.
# Below a threshold the wiki gives no odds, so the chance ramps up linearly.
# Chests hold coins and (from B up) materials, rarer with each grade.
# Pure + rng-injected so it is easy to unit-test.

const _MATERIAL_LIST_PATH := "res://items/material_list.tres"

# Per-unit Luck caps at 100 (jobs/job.gd), so average_luck is 0..100.
const A_GUARANTEE := 40.0
const B_GUARANTEE := 85.0
const C_CHANCE_AT_CAP := 0.5
const D_CHANCE_AT_CAP := 0.25


# Chance of each chest grade [A, B, C, D] at the given average Luck.
static func chest_chances(average_luck: float) -> Array:
	var luck: float = clampf(average_luck, 0.0, 100.0)

	var a: float = clampf(luck / A_GUARANTEE, 0.0, 1.0)
	var b: float = clampf((luck - A_GUARANTEE) / (B_GUARANTEE - A_GUARANTEE), 0.0, 1.0)
	var c: float = clampf((luck - B_GUARANTEE) / (100.0 - B_GUARANTEE), 0.0, 1.0) * C_CHANCE_AT_CAP
	var d: float = D_CHANCE_AT_CAP if luck >= 100.0 else 0.0

	return [a, b, c, d]


# Returns { "coins": int, "materials": { id: count }, "chests": int }.
# average_luck is the squad's mean Luck (0..100).
static func roll(average_luck: float, rng: RandomNumberGenerator) -> Dictionary:
	var chances: Array = chest_chances(average_luck)
	var coins: int = 0
	var materials: Dictionary = {}
	var chests: int = 0

	var pool: Array = _material_pool()

	# A chest: coins.
	if rng.randf() < chances[0]:
		chests += 1
		coins += 40 + rng.randi_range(0, 40)

	# B chest: coins, sometimes a common material.
	if rng.randf() < chances[1]:
		chests += 1
		coins += 60 + rng.randi_range(0, 60)

		if rng.randf() < 0.35:
			_add_material(materials, _pick_material(pool, 1, rng))

	# C chest: a rarer material plus coins.
	if rng.randf() < chances[2]:
		chests += 1
		coins += 40 + rng.randi_range(0, 40)
		_add_material(materials, _pick_material(pool, 2, rng))

	# D chest: the rarest material plus a coin pile.
	if rng.randf() < chances[3]:
		chests += 1
		coins += 80 + rng.randi_range(0, 80)
		_add_material(materials, _pick_material(pool, 3, rng))

	return {"coins": coins, "materials": materials, "chests": chests}


static func _add_material(materials: Dictionary, item) -> void:
	if item != null:
		materials[item.id] = int(materials.get(item.id, 0)) + 1


static func _material_pool() -> Array:
	var list = load(_MATERIAL_LIST_PATH)

	return list.materials() if list != null else []


# Higher chest grades unlock rarer materials (rarity up to max_rarity).
static func _pick_material(pool: Array, max_rarity: int, rng: RandomNumberGenerator):
	var eligible := []

	for item in pool:
		if item.rarity <= max_rarity:
			eligible.append(item)

	if eligible.is_empty():
		return null

	return eligible[rng.randi_range(0, eligible.size() - 1)]
