extends Node
## Room transport and host-authoritative simulation. No high-level RPC or remote code.
signal changed
signal rooms_changed
var rooms: Array = []
var browsing := false
var _browser: WebSocketPeer
var _list_elapsed := 2.0
const FISH := preload("res://scenes/fish/Fish.tscn")
var relay_url := "wss://fish.40-160-53-64.sslip.io/relay"
var mode := ""
var code := ""
var status := ""
var socket: WebSocketPeer
var _request: Dictionary = {}
var _elapsed := 0.0
var _snapshot_time := 0.0
var _selected: Node
var _guests: Dictionary = {}
var _view: Node2D
var _visuals: Dictionary = {}
var _gift_wait := false
var _host_id := ""
var _retry_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func tank() -> Node:
	return get_tree().get_first_node_in_group("tank")

func visiting() -> bool:
	return mode == "visitor"

func set_player_name(_value: String) -> void:
	GameState.player_name = Account.username

func owned_count() -> int:
	var count := 0
	if tank() != null:
		for fish in tank().get_node("Fishes").get_children():
			if not fish.has_meta("visitor") and not fish.is_queued_for_deletion():
				count += 1
	return count

func can_gift() -> bool:
	return Account.is_logged_in() and visiting() and is_instance_valid(_selected) and owned_count() >= 2 and not _gift_wait

func open_tank() -> void:
	if not Account.is_logged_in():
		status = "Log in to visit tanks."
		changed.emit()
		return
	if mode.is_empty() and tank() != null:
		SaveManager.save_game()
		_connect({"op": "host", "name": GameState.player_name,
			"fish_count": tank().get_node("Fishes").get_child_count()}, "hosting")

func visit(room: String, fish: Node) -> void:
	if not Account.is_logged_in():
		return
	SaveManager.save_game()
	await Account.flush_now()
	if not mode.is_empty() or tank() == null:
		return
	var pending := not GameState.gift_outbox.is_empty()
	if not pending and (not is_instance_valid(fish) or fish.is_queued_for_deletion() or fish.has_meta("visitor") or fish.get_parent() != tank().get_node("Fishes")):
		return
	_selected = fish
	code = room.strip_edges().to_upper()
	_connect({"op": "join", "code": code, "name": GameState.player_name,
		"fish": {"id": fish.fish_id, "data": GameState.gift_outbox.data if pending else fish.data.resource_path,
		"fullness": 1.0 if pending else fish.fullness,
		"tier": GameState.gift_outbox.get("tier", 0) if pending else fish.tier}}, "joining")

func _connect(request: Dictionary, next_mode: String) -> void:
	await Account.flush_now()
	socket = WebSocketPeer.new()
	_request = request
	mode = next_mode
	_elapsed = 0.0
	status = "Connecting..."
	if socket.connect_to_url(relay_url) != OK:
		leave("Cannot connect to relay.")
	changed.emit()

func _send(message: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		message["token"] = Account.token
		socket.send_text(JSON.stringify(message))

func _to_guest(id: String, body: Dictionary) -> void:
	_send({"op": "send", "to": id, "body": body})

func _to_host(body: Dictionary) -> void:
	_send({"op": "send", "body": body})

func _process(delta: float) -> void:
	_poll_rooms(delta)
	if socket == null:
		return
	socket.poll()
	_elapsed += delta
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not _request.is_empty():
			_send(_request)
			_request = {}
		while socket != null and socket.get_available_packet_count() > 0:
			var message: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if message is Dictionary:
				_receive(message)
	elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		leave("Disconnected. Back in your tank.")
		return
	if mode in ["joining", "hosting"] and _elapsed > 10.0:
		leave("Connection timed out.")
		return
	if mode == "host":
		if tank() == null:
			leave()
			return
		_snapshot_time += delta
		if _snapshot_time >= 0.1:
			_snapshot_time = 0.0
			_send({"op": "broadcast", "body": _snapshot()})
	if visiting() and is_instance_valid(_view) and not get_tree().paused:
		for visual in _visuals.values():
			visual.position = visual.position.lerp(visual.get_meta("target"), minf(delta * 15.0, 1.0))

func _receive(m: Dictionary) -> void:
	match str(m.get("op", "")):
		"hosted":
			mode = "host"
			code = str(m.get("code", ""))
			status = "Tank open to everyone"
		"joined":
			mode = "visitor"
			status = "Visiting a public tank"
			_host_id = ""
			_show_visit()
		"arrival":
			if mode == "host":
				_arrival(m)
		"departure":
			_remove_guest(str(m.get("id", "")))
		"message":
			if mode == "host" and m.get("body") is Dictionary:
				_host_message(str(m.get("id", "")), m.body)
		"snapshot":
			if visiting():
				_render(m)
		"earn":
			if visiting() and m.get("amount") is float and is_finite(m.amount) and m.amount >= 0 and m.amount <= 10000:
				GameState.add_money(int(m.amount))
				SaveManager.save_game()
		"gift_received":
			if mode == "host" and m.get("fish") is Dictionary:
				_accept_cloud_gift(m)
		"gift_sent":
			if visiting() and is_instance_valid(_selected) and str(m.get("fish_id", "")) == _selected.fish_id:
				_selected.get_parent().remove_child(_selected)
				_selected.queue_free()
				_selected = null
				_gift_wait = false
				if m.get("save") is Dictionary:
					SaveManager.write_cache(m.save)
				SaveManager.save_game()
				status = "Fish gifted!"
		"closed", "error":
			leave("Room error: " + str(m.get("code", "unknown")) if m.get("op") == "error" else "Tank closed. Back in your tank.")
	changed.emit()

func fish_data(path: Variant) -> FishData:
	# Only shipped catalog resources. Never load arbitrary peer-supplied resources/scripts.
	if not path is String or not path.begins_with("res://data/fish/") or "/" in path.trim_prefix("res://data/fish/") or not path.ends_with(".tres"):
		return null
	if not ResourceLoader.exists(path):
		return null
	return load(path) as FishData

func _arrival(m: Dictionary) -> void:
	var id := str(m.get("id", ""))
	if _guests.has(id) or not m.get("fish") is Dictionary:
		return
	var data := fish_data(m.fish.get("data"))
	if data == null or not FishTier.valid(m.fish.get("tier", 0)):
		return
	var fish := FISH.instantiate()
	fish.fish_id = str(m.fish.get("id", fish.fish_id))
	fish.tier = int(m.fish.get("tier", 0))
	fish.data = data
	fish.set_meta("visitor", id)
	fish.position = tank().navigator.random_open_point()
	tank().get_node("Fishes").add_child(fish)
	var fullness: Variant = m.fish.get("fullness", 1.0)
	if SaveManager._number(fullness):
		fish.fullness = clampf(float(fullness), 0.0, 1.0)
	var label := Label.new()
	label.text = str(m.get("name", "Player")).left(24)
	label.position = Vector2(-32, -44)
	fish.add_child(label)
	_guests[id] = {"fish": fish, "name": label.text, "last_food": -1000}
	_to_guest(id, _snapshot())

func _remove_guest(id: String) -> void:
	if not _guests.has(id):
		return
	var fish: Node = _guests[id].fish
	if is_instance_valid(fish) and fish.has_meta("visitor"):
		fish.get_parent().remove_child(fish)
		fish.queue_free()
	_guests.erase(id)

func _host_message(id: String, body: Dictionary) -> void:
	if not _guests.has(id) or tank() == null:
		return
	match str(body.get("op", "")):
		"food":
			if get_tree().paused or Time.get_ticks_msec() - _guests[id].last_food < 150:
				return
			var pos: Variant = body.get("position")
			if not pos is Array or pos.size() != 2 or not SaveManager._number(pos[0]) or not SaveManager._number(pos[1]):
				return
			var point := Vector2(pos[0], pos[1])
			if not tank().bounds.has_point(point):
				return
			_guests[id].last_food = Time.get_ticks_msec()
			tank().drop_food(point, null, 1.0, id)
func _clear_guest_fish(id: String) -> void:
	var guest: Node = _guests[id].fish
	if is_instance_valid(guest) and guest.has_meta("visitor"):
		guest.get_parent().remove_child(guest)
		guest.queue_free()
	_guests[id].fish = null

func payout(fish: Node, amount: int, feeder: String) -> void:
	var owner := str(fish.get_meta("visitor", ""))
	if mode == "host" and not owner.is_empty():
		_to_guest(owner, {"op": "earn", "amount": amount})
	else:
		Events.fish_fed.emit(fish, amount)
		if mode == "host" and not feeder.is_empty():
			_to_guest(feeder, {"op": "earn", "amount": roundi(amount * 0.2)})

func request_food(point: Vector2) -> void:
	_to_host({"op": "food", "position": [point.x, point.y]})

func gift() -> void:
	if not can_gift():
		status = "Keep at least one fish in your tank."
		changed.emit()
		return
	SaveManager.save_game()
	await Account.flush_now()
	if not can_gift():
		return
	_gift_wait = true
	_send({"op": "gift", "fish_id": _selected.fish_id,
		"transfer_id": Crypto.new().generate_random_bytes(16).hex_encode()})
	status = "Sending gift..."
	changed.emit()

func _accept_cloud_gift(message: Dictionary) -> void:
	var entry: Dictionary = message.fish
	if message.get("save") is Dictionary:
		SaveManager.write_cache(message.save)
	var data := fish_data(entry.get("data"))
	if data == null or not FishTier.valid(entry.get("tier", 0)):
		return
	for existing in tank().get_node("Fishes").get_children():
		if not existing.has_meta("visitor") and existing.fish_id == str(entry.get("id", "")):
			return
	var fish := FISH.instantiate()
	fish.fish_id = str(entry.get("id", fish.fish_id))
	fish.data = data
	fish.tier = int(entry.get("tier", 0))
	fish.position = tank().navigator.random_open_point()
	tank().get_node("Fishes").add_child(fish)
	for id in _guests.keys():
		if is_instance_valid(_guests[id].fish) and _guests[id].fish.fish_id == fish.fish_id:
			_clear_guest_fish(id)
	SaveManager.save_game()
	status = "A new fish joined your tank!"

func _snapshot() -> Dictionary:
	var fishes: Array = []
	var pellets: Array = []
	for fish in tank().get_node("Fishes").get_children():
		fishes.append({"id": str(fish.get_instance_id()), "data": fish.data.resource_path, "tier": fish.tier,
			"position": [fish.position.x, fish.position.y], "flip": fish.get_node("Sprite2D").flip_h,
			"name": str(_guests.get(str(fish.get_meta("visitor", "")), {}).get("name", ""))})
	for food in tank().get_node("Food").get_children():
		if not food.is_queued_for_deletion():
			pellets.append({"id": "p" + str(food.get_instance_id()), "position": [food.position.x, food.position.y]})
	return {"op": "snapshot", "host": GameState.tank_id, "fish": fishes, "food": pellets}

func _show_visit() -> void:
	SaveManager.save_game()
	for path in ["Fishes", "Food", "Maintenance"]:
		tank().get_node(path).hide()
		tank().get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	_view = Node2D.new()
	tank().add_child(_view)

func _render(m: Dictionary) -> void:
	_host_id = str(m.get("host", ""))
	if not is_instance_valid(_view) or not m.get("fish") is Array or not m.get("food") is Array:
		return
	var seen: Dictionary = {}
	for entry in m.fish + m.food:
		if not entry is Dictionary or not entry.get("position") is Array or entry.position.size() != 2:
			continue
		if not SaveManager._number(entry.position[0]) or not SaveManager._number(entry.position[1]):
			continue
		var id := str(entry.get("id", ""))
		seen[id] = true
		var point := Vector2(entry.position[0], entry.position[1])
		if not _visuals.has(id):
			var sprite := Sprite2D.new()
			if id.begins_with("p"):
				sprite.texture = preload("res://assets/food/pellet.png")
			else:
				var data := fish_data(entry.get("data"))
				if data == null:
					continue
				sprite.texture = data.sprite
				var tier: Variant = entry.get("tier", 0)
				if not FishTier.valid(tier):
					sprite.free()
					continue
				FishTier.style(sprite, int(tier))
				var label := Label.new()
				label.text = str(entry.get("name", "")).left(24)
				label.position = Vector2(-32, -44)
				sprite.add_child(label)
			sprite.position = point
			_view.add_child(sprite)
			_visuals[id] = sprite
		_visuals[id].set_meta("target", point)
		_visuals[id].flip_h = bool(entry.get("flip", false))
	for id in _visuals.keys():
		if not seen.has(id):
			_visuals[id].queue_free()
			_visuals.erase(id)

func leave(message: String = "Back in your tank.") -> void:
	if socket != null:
		socket.close()
		socket = null
	for id in _guests.keys():
		_remove_guest(id)
	if is_instance_valid(_view):
		_view.queue_free()
	_view = null
	_visuals.clear()
	if visiting() and tank() != null:
		for path in ["Fishes", "Food", "Maintenance"]:
			tank().get_node(path).show()
			tank().get_node(path).process_mode = Node.PROCESS_MODE_INHERIT
	mode = ""
	code = ""
	_selected = null
	_gift_wait = false
	status = message
	SaveManager.save_game()
	changed.emit()


func browse_rooms(active: bool) -> void:
	browsing = active
	if not active:
		if _browser != null:
			_browser.close()
		_browser = null
		return
	_list_elapsed = 2.0
	_poll_rooms(0.0)

func _poll_rooms(delta: float) -> void:
	if not browsing or not Account.is_logged_in():
		return
	if _browser == null:
		_browser = WebSocketPeer.new()
		if _browser.connect_to_url(relay_url) != OK:
			_browser = null
			return
	_browser.poll()
	_list_elapsed += delta
	if _browser.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if _list_elapsed >= 2.0:
			_list_elapsed = 0.0
			_browser.send_text(JSON.stringify({"op": "list", "token": Account.token}))
		while _browser.get_available_packet_count() > 0:
			var reply: Variant = JSON.parse_string(_browser.get_packet().get_string_from_utf8())
			if reply is Dictionary and reply.get("op") == "rooms" and reply.get("rooms") is Array:
				rooms = reply.rooms.slice(0, 128)
				rooms_changed.emit()
	elif _browser.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_browser = null
		rooms = []
		rooms_changed.emit()
