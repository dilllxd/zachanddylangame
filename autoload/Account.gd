extends Node
## HTTPS account sessions. Local cache is isolated per account, never shared on logout.
signal changed
const API := "https://fish.40-160-53-64.sslip.io/api"
const SESSION := "user://session.json"
var username := ""
var token := ""
var busy := false
var status := ""
var offline := false
var _verified := false
var _pending: Dictionary = {}
var _uploading := false
var _remember := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(SESSION):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSION))
		if saved is Dictionary:
			token = str(saved.get("token", ""))
			username = str(saved.get("username", ""))
			if not username.is_empty():
				SaveManager.SAVE_PATH = _cache_path()

func _cache_path() -> String:
	return "user://account_" + username.to_lower() + ".json"

func is_logged_in() -> bool:
	return not token.is_empty() and not username.is_empty() and not offline and _verified

func has_offline_cache() -> bool:
	return not username.is_empty() and FileAccess.file_exists(_cache_path())

func play_offline() -> void:
	offline = true
	SaveManager.SAVE_PATH = _cache_path()
	GameState.player_name = username

func _request(method: int, path: String, body: Dictionary = {}) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 12
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var error := http.request(API + path, headers, method, JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if error != OK:
		http.queue_free()
		return {"error": "Cannot reach cloud. Your local progress is safe."}
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Cannot reach cloud. Your local progress is safe."}
	var parsed: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	if not parsed is Dictionary:
		return {"error": "Cloud returned an invalid response."}
	if result[1] < 200 or result[1] >= 300:
		return {"error": str(parsed.get("error", "Request failed")).replace("_", " ")}
	return parsed

func login(name_value: String, password: String, remember: bool) -> void:
	await _authenticate("/login", name_value, password, remember)

func signup(name_value: String, password: String, remember: bool) -> void:
	await _authenticate("/signup", name_value, password, remember)

func _authenticate(path: String, name_value: String, password: String, remember: bool) -> void:
	if busy:
		return
	busy = true
	status = "Connecting to your aquarium..."
	changed.emit()
	var body := {"username": name_value.strip_edges(), "password": password}
	if path == "/signup" and not FileAccess.file_exists("user://legacy_migrated") and SaveManager.SAVE_PATH == "user://save.json":
		body["save"] = _with_ids(SaveManager.cached_record())
	var reply := await _request(HTTPClient.METHOD_POST, path, body)
	if reply.has("error"):
		status = str(reply.error)
	else:
		username = str(reply.get("username", ""))
		token = str(reply.get("token", ""))
		_remember = remember
		_verified = true
		offline = false
		SaveManager.SAVE_PATH = _cache_path()
		GameState.player_name = username
		var cloud: Dictionary = reply.get("save", {})
		var local := SaveManager.cached_record()
		if not local.is_empty() and float(local.get("saved_at", 0)) > float(cloud.get("saved_at", 0)):
			var merged := await _request(HTTPClient.METHOD_PUT, "/save", {"save": _with_ids(local)})
			if merged.has("save"):
				cloud = merged.save
		if not cloud.is_empty():
			SaveManager.write_cache(cloud)
		if path == "/signup":
			var marker := FileAccess.open("user://legacy_migrated", FileAccess.WRITE)
			if marker:
				marker.store_string("1")
		_store_session()
		status = "Welcome, " + username
	busy = false
	changed.emit()

func resume() -> bool:
	if token.is_empty() or username.is_empty() or busy:
		return false
	busy = true
	status = "Opening your aquarium..."
	changed.emit()
	var me := await _request(HTTPClient.METHOD_GET, "/me")
	if me.has("error"):
		status = str(me.error)
		busy = false
		changed.emit()
		return false
	username = str(me.get("username", username))
	SaveManager.SAVE_PATH = _cache_path()
	var reply := await _request(HTTPClient.METHOD_GET, "/save")
	if reply.has("error"):
		status = str(reply.error)
		busy = false
		changed.emit()
		return false
	var cloud: Dictionary = reply.get("save", {})
	var local := SaveManager.cached_record()
	if not local.is_empty() and float(local.get("saved_at", 0)) > float(cloud.get("saved_at", 0)):
		reply = await _request(HTTPClient.METHOD_PUT, "/save", {"save": _with_ids(local)})
		if reply.has("save"):
			cloud = reply.save
	if not cloud.is_empty():
		SaveManager.write_cache(cloud)
	_verified = true
	offline = false
	GameState.player_name = username
	busy = false
	status = "Welcome back, " + username
	changed.emit()
	return true

func _store_session() -> void:
	if not _remember:
		if FileAccess.file_exists(SESSION):
			DirAccess.remove_absolute(SESSION)
		return
	var file := FileAccess.open(SESSION, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"username": username, "token": token}))

func logout() -> void:
	Net.leave()
	Net.browse_rooms(false)
	_verified = false
	token = ""
	username = ""
	offline = false
	_pending = {}
	SaveManager.SAVE_PATH = "user://save.json"
	if FileAccess.file_exists(SESSION):
		DirAccess.remove_absolute(SESSION)
	changed.emit()

func _with_ids(record: Dictionary) -> Dictionary:
	for fish in record.get("fish", []):
		if fish is Dictionary and str(fish.get("id", "")).is_empty():
			fish["id"] = Crypto.new().generate_random_bytes(16).hex_encode()
	return record

func queue_save(record: Dictionary) -> void:
	if not is_logged_in():
		return
	_pending = record.duplicate(true)
	if not _uploading:
		_flush.call_deferred()

func _flush() -> void:
	if _uploading or _pending.is_empty() or not is_logged_in():
		return
	_uploading = true
	var record := _pending
	_pending = {}
	var session_token := token
	var reply := await _request(HTTPClient.METHOD_PUT, "/save", {"save": record})
	if token == session_token:
		if reply.has("save"):
			# Do not replace a newer unsent cache with an older upload response.
			if _pending.is_empty():
				SaveManager.write_cache(reply.save)
		else:
			status = "Offline cache saved. Cloud sync will retry on your next save."
			changed.emit()
	_uploading = false
	if not _pending.is_empty():
		_flush.call_deferred()

func flush_now() -> void:
	if not _pending.is_empty() and not _uploading:
		await _flush()
	while _uploading:
		await get_tree().process_frame
