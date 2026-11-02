extends SceneTree
var main: Node
var tank: Node
var sm: Node
var gs: Node
var FISH: PackedScene
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		push_error(text)
		quit(1)
		assert(ok, text)
	print("PASS ", text)
func spawn(data: FishData, tier: int) -> Node:
	var f = FISH.instantiate()
	f.data = data
	f.tier = tier
	f.position = Vector2(200, 100)
	tank.get_node("Fishes").add_child(f)
	f.fullness = 0.5
	return f
func run() -> void:
	FISH = load("res://scenes/fish/Fish.tscn")
	sm = root.get_node("SaveManager")
	gs = root.get_node("GameState")
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	tank = get_first_node_in_group("tank")
	var data = load("res://data/fish/goldfish.tres")
	var own = tank.get_node("Fishes").get_child(0)
	own.fullness = 0.5
	spawn(data, 0)
	var third = spawn(data, 0)
	var guest = spawn(data, 0)
	guest.set_meta("visitor", "test")
	gs.money = 49
	check(tank.merge_fish(data, 0) == null and gs.money == 49, "insufficient funds rejected atomically")
	var shop = main.get_node("UI/Shop")
	shop._refresh_merges()
	check(shop._merge_rows.get_child(-1).disabled, "merge button disabled below fee")
	gs.money = 100
	shop._refresh_merges()
	check(not shop._merge_rows.get_child(-1).disabled, "merge affordable UI")
	paused = true
	check(tank.merge_fish(data, 0) == null, "paused merge blocked")
	paused = false
	root.get_node("Net").mode = "visitor"
	check(tank.merge_fish(data, 0) == null, "away merge blocked")
	root.get_node("Net").mode = ""
	third.tier = 1
	check(tank.merge_fish(data, 0) == null, "mixed tiers and visitor excluded")
	third.tier = 0
	var merged = tank.merge_fish(data, 0)
	check(merged != null and merged.tier == 1 and gs.money == 50, "3 Goldys plus 50 becomes Golden Goldy")
	check(tank.get_node("Fishes").get_child_count() == 2 and is_instance_valid(guest), "exactly 3 owned consumed guest untouched")
	check(is_equal_approx(merged.fullness, 0.5), "fullness averaged")
	check(FishTier.title(data, merged.tier) == "Golden Goldy" and FishTier.payout(data, merged.tier) == 20, "name and quadruple payout")
	tank.drop_food(Vector2(200, 100), null, 0.5)
	merged.eat(tank.get_node("Food").get_child(-1))
	check(gs.money == 60, "recycled pellet uses tier payout")
	guest.get_parent().remove_child(guest)
	guest.queue_free()
	sm.save_game()
	var record = JSON.parse_string(FileAccess.get_file_as_string(sm.SAVE_PATH))
	check(record.fish.size() == 1 and record.fish[0].tier == 1 and record.money == 60, "merge saved immediately")
	main.free()
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	tank = get_first_node_in_group("tank")
	merged = tank.get_node("Fishes").get_child(0)
	check(merged.tier == 1 and gs.money == 60, "tier persists on reload")
	gs.upgrades = {"roomba": true}
	record.saved_at = int(Time.get_unix_time_from_system()) - 3600
	var resources: Array[FishData] = [data]
	check(sm.offline_credit(record, resources) == 600, "tiered offline 600 per hour")
	gs.money = 100000
	for tier in [1, 2]:
		spawn(data, tier)
		spawn(data, tier)
		var before = gs.money
		merged = tank.merge_fish(data, tier)
		check(merged != null and merged.tier == tier + 1 and gs.money == before - FishTier.fee(data, tier), "next tier fee " + str(tier))
	check(FishTier.title(data, 3) == "Royal Goldy" and FishTier.payout(data, 3) == 320, "Royal tier pays 320")
	spawn(data, 3)
	spawn(data, 3)
	check(tank.merge_fish(data, 3) == null, "max tier cannot merge")
	sm.save_game()
	record = JSON.parse_string(FileAccess.get_file_as_string(sm.SAVE_PATH))
	for entry in record.fish:
		entry.erase("tier")
	record.upgrades = {}
	var file = FileAccess.open(sm.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(record))
	file.close()
	main.free()
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	tank = get_first_node_in_group("tank")
	check(tank.get_node("Fishes").get_child(0).tier == 0, "old save migrates tier zero")
	check(not FishTier.valid(-1) and not FishTier.valid(4) and not FishTier.valid(1.5) and not FishTier.valid("1"), "invalid tiers rejected")
	sm.enabled = false
	main.free()
	print("MERGE TESTS PASSED")
	quit()
