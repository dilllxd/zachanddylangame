extends Node

const SAVE_PATH := "user://save.json"
const FISH_SCENE := preload("res://scenes/fish/Fish.tscn")

# Tests can disable all disk access before instantiating Main.
var enabled := true
var last_save_ok := false
var _loading := false
var _timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 5.0
	add_child(_timer)
	_timer.timeout.connect(save_game)
	Events.money_changed.connect(_on_money_changed)

func _on_money_changed(_total: int) -> void:
	if enabled and not _loading and _timer.is_stopped():
		_timer.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func save_game() -> void:
	last_save_ok = false
	if not enabled or _loading:
		return
	var tank := get_tree().get_first_node_in_group("tank")
	# Title screen has no tank. Never overwrite the fish with an empty list.
	if tank == null or not tank.is_node_ready():
		return
	_timer.stop()
	var fish_records: Array = []
	for fish in tank.get_node("Fishes").get_children():
		if fish.has_meta("visitor"):
			continue
		if fish.data == null or fish.data.resource_path.is_empty():
			push_warning("Cannot save fish without a FishData resource path.")
			return
		fish_records.append({
			"data": fish.data.resource_path,
			"fullness": fish.fullness,
			"position": [fish.position.x, fish.position.y],
		})
	if GameState.tank_id.is_empty():
		GameState.tank_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var record := {
		"version": 1,
		"tank_id": GameState.tank_id,
		"gift_outbox": GameState.gift_outbox,
		"gift_receipts": GameState.gift_receipts,
		"saved_at": int(Time.get_unix_time_from_system()),
		"money": GameState.money,
		"player_name": GameState.player_name,
		"fish": fish_records,
	}
	# Replace only after the complete JSON has been written successfully.
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save file.")
		return
	file.store_string(JSON.stringify(record, "	"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH) != OK:
		push_warning("Could not finish saving game.")
		return
	last_save_ok = true

# Called by Tank once its children are ready. False means use default Goldy.
func load_tank(tank: Node2D) -> bool:
	if not enabled or not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("Save file is corrupt; starting with Goldy.")
		return false
	var record: Variant = json.data
	if not record is Dictionary or record.get("version") != 1:
		return false
	if not _number(record.get("money")) or record.money < 0 or not record.get("fish") is Array:
		return false
	# Validate everything before changing the tank or GameState.
	var resources: Array[FishData] = []
	for entry in record.fish:
		if not entry is Dictionary or not entry.get("data") is String:
			return false
		var path: String = entry.data
		if not path.begins_with("res://data/fish/") or not ResourceLoader.exists(path):
			return false
		var data := load(path) as FishData
		var pos: Variant = entry.get("position")
		if data == null or not _number(entry.get("fullness")):
			return false
		if not pos is Array or pos.size() != 2 or not _number(pos[0]) or not _number(pos[1]):
			return false
		resources.append(data)
	_loading = true
	GameState.tank_id = str(record.get("tank_id", ""))
	GameState.gift_outbox = record.get("gift_outbox", {}) if record.get("gift_outbox", {}) is Dictionary else {}
	GameState.gift_receipts = record.get("gift_receipts", {}) if record.get("gift_receipts", {}) is Dictionary else {}
	GameState.money = int(record.money)
	GameState.player_name = str(record.get("player_name", "Player")).left(24)
	for i in record.fish.size():
		var entry: Dictionary = record.fish[i]
		var fish := FISH_SCENE.instantiate()
		fish.data = resources[i]
		fish.position = Vector2(entry.position[0], entry.position[1]).clamp(tank.bounds.position, tank.bounds.end)
		tank.get_node("Fishes").add_child(fish)
		fish.fullness = clampf(entry.fullness, 0.0, 1.0)
	Events.money_changed.emit(GameState.money)
	_loading = false
	return true

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
