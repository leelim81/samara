extends SceneTree
# Tests the Purchase helper (coins + materials affordability and spending).
#   godot --headless --script res://tools/test_purchase.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var sd = load("res://save_data/save_data.gd").new()
	sd.coins = 500
	sd.add_item("scrap", 2)

	_check("afford coins only", Purchase.can_afford(sd, 300))
	_check("not afford too many coins", not Purchase.can_afford(sd, 600))
	_check("afford coins + materials", Purchase.can_afford(sd, 100, {"scrap": 2}))
	_check("not afford missing materials", not Purchase.can_afford(sd, 100, {"scrap": 3}))

	_check("spend succeeds", Purchase.spend(sd, 200, {"scrap": 1}))
	_check("coins deducted", sd.coins == 300)
	_check("material deducted", sd.item_count("scrap") == 1)

	_check("spend fails when short on coins", not Purchase.spend(sd, 9999))
	_check("coins unchanged after failed spend", sd.coins == 300)
	_check("spend fails when short on materials", not Purchase.spend(sd, 0, {"scrap": 5}))
	_check("materials unchanged after failed spend", sd.item_count("scrap") == 1)

	print("test_purchase: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1

	print(("  PASS " if cond else "  FAIL ") + label)
