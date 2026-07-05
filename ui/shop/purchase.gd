class_name Purchase
extends RefCounted
# Shared affordability + spend helper for every coin/material purchase (the
# market, training, and the upgrade sinks in G3/G4/G5). material_costs maps an
# item id to the required count.


static func can_afford(save_data: SaveData, coin_cost: int, material_costs: Dictionary = {}) -> bool:
	if save_data == null or save_data.coins < coin_cost:
		return false

	for item_id in material_costs:
		if save_data.item_count(item_id) < int(material_costs[item_id]):
			return false

	return true


# Spends the coins and materials if the player can afford them. Returns false
# (and changes nothing) otherwise.
static func spend(save_data: SaveData, coin_cost: int, material_costs: Dictionary = {}) -> bool:
	if not can_afford(save_data, coin_cost, material_costs):
		return false

	save_data.coins -= coin_cost

	for item_id in material_costs:
		save_data.remove_item(item_id, int(material_costs[item_id]))

	return true
