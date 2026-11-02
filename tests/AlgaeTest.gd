extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		push_error(text)
		quit(1)
		assert(ok, text)
	print("PASS ", text)
func run() -> void:
	var sm = root.get_node("SaveManager")
	var gs = root.get_node("GameState")
	var net = root.get_node("Net")
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var tank = get_first_node_in_group("tank")
	var shop = main.get_node("UI/Shop")
	gs.money = 500
	shop._buy_roomba()
	check(gs.money == 350 and gs.upgrades.get("roomba"), "roomba costs 150")
	shop._buy_roomba()
	check(gs.money == 350 and tank.get_node("Maintenance").has_node("Roomba"), "single purchase")
	var robot = tank.get_node("Maintenance/Roomba")
	tank.get_node("Fishes").process_mode = Node.PROCESS_MODE_DISABLED
	var algae = tank.get_node("Maintenance/Algae")
	check(algae.get_child_count() == 0, "no initial waste")
	algae._process(12.0)
	check(algae.get_child_count() == 1, "algae grows with time not feeding")
	for patch in algae.get_children():
		patch.free()
	for i in 3:
		algae.grow_patch(robot.along)
	await create_timer(2.5).timeout
	check(robot.produced == 1 and robot.collected == 0, "three algae patches produce pellet")
	var pellet = tank.get_node("Food").get_child(0)
	check(pellet.payout_mult == 0.5 and pellet.position.y < tank.bounds.end.y, "half payout ejected food")
	pellet.position.y = pellet.floor_y
	pellet.lifetime = 0.01
	await create_timer(0.1).timeout
	check(tank.get_node("Food").get_child_count() == 0 and algae.get_child_count() == 0, "old food expires without waste")
	tank.drop_food(Vector2(100, 100))
	var fading = tank.get_node("Food").get_child(0)
	fading.position.y = fading.floor_y
	fading._rest_time = 18.0
	fading._process(0.1)
	check(fading.modulate.a < 1.0 and fading.modulate.a > 0.0, "landed food fades")
	fading.queue_free()
	paused = true
	var pos = robot.position
	await create_timer(0.2, true).timeout
	check(robot.position == pos, "pause freezes roomba")
	paused = false
	net.mode = "visitor"
	net._show_visit()
	check(not tank.get_node("Maintenance").visible and tank.get_node("Maintenance").process_mode == Node.PROCESS_MODE_DISABLED, "maintenance hidden frozen away")
	net.leave()
	check(tank.get_node("Maintenance").visible, "maintenance restored home")
	for i in 100:
		algae.grow_patch()
	check(algae.get_child_count() == 48, "algae cap48")
	robot.along = algae.edge.size.x + 50.0
	robot._process(0.01)
	check(robot.position.x > tank.bounds.end.x - 20.0 and robot.position.y < tank.bounds.end.y - 20.0, "roomba climbs side wall")
	sm.save_game()
	var record = JSON.parse_string(FileAccess.get_file_as_string(sm.SAVE_PATH))
	record.saved_at = int(Time.get_unix_time_from_system()) - 3600
	var file = FileAccess.open(sm.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(record))
	file.close()
	main.free()
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(gs.money == 530, "one hour Goldy offline credits 180")
	check(get_first_node_in_group("tank").get_node("Maintenance").has_node("Roomba"), "ownership restored")
	record = JSON.parse_string(FileAccess.get_file_as_string(sm.SAVE_PATH))
	check(record.money == 530 and absf(Time.get_unix_time_from_system() - record.saved_at) < 5, "credit timestamp persisted")
	main.free()
	main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(gs.money == 530, "reload does not double credit")
	var resources: Array[FishData] = [load("res://data/fish/goldfish.tres")]
	record.saved_at = int(Time.get_unix_time_from_system()) - 86400
	check(sm.offline_credit(record, resources) == 1440, "offline capped at eight hours")
	record.saved_at = int(Time.get_unix_time_from_system()) + 500
	check(sm.offline_credit(record, resources) == 0, "future timestamp zero")
	gs.upgrades = {}
	record.saved_at = 0
	check(sm.offline_credit(record, resources) == 0, "no roomba no offline")
	sm.enabled = false
	main.free()
	print("ROOMBA TESTS PASSED")
	quit()
