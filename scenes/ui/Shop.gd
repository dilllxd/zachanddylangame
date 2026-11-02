extends Control

var catalog: Array[FishData] = []
var _buttons: Array[Button] = []
var _roomba_button: Button
var _roomba := preload("res://data/upgrades/roomba.tres")
@onready var panel: PanelContainer = $Panel
@onready var rows: VBoxContainer = $Panel/Margin/Content/Scroll/Rows

func _ready() -> void:
	panel.hide()
	$Toggle.pressed.connect(_toggle)
	Events.money_changed.connect(_update_affordability)
	# ResourceLoader handles remapped resources in exported builds too.
	for filename in ResourceLoader.list_directory("res://data/fish/"):
		if filename.ends_with(".tres"):
			var data := load("res://data/fish/" + filename) as FishData
			if data != null and data.price >= 0:
				catalog.append(data)
	catalog.sort_custom(func(a: FishData, b: FishData) -> bool: return a.price < b.price)
	for data in catalog:
		_add_row(data)
	var heading := Label.new()
	heading.text = "Upgrades"
	rows.add_child(heading)
	var detail := Label.new()
	detail.text = "Sand Roomba · $150\n3 scraps = half-value food\nOffline earnings, up to 8 hours"
	rows.add_child(detail)
	_roomba_button = Button.new()
	_roomba_button.custom_minimum_size.y = 44
	_roomba_button.pressed.connect(_buy_roomba)
	rows.add_child(_roomba_button)
	_update_affordability(GameState.money)

func _process(_delta: float) -> void:
	# Always processing keeps this hidden throughout pause, including external pauses.
	visible = not get_tree().paused and not Net.visiting()

func _toggle() -> void:
	if not get_tree().paused:
		panel.visible = not panel.visible
		$Toggle.text = "Close shop" if panel.visible else "Fish shop"

func _add_row(data: FishData) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = data.sprite
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var info := Label.new()
	info.text = "%s  ·  $%d\n$%d per pellet" % [data.name, data.price, data.pellet_value]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var buy := Button.new()
	buy.text = "Buy"
	buy.custom_minimum_size = Vector2(60, 44)
	buy.pressed.connect(_buy.bind(data))
	row.add_child(buy)
	rows.add_child(row)
	_buttons.append(buy)

func _buy_roomba() -> void:
	if get_tree().paused or Net.visiting() or GameState.upgrades.get("roomba", false):
		return
	if GameState.spend(_roomba.cost):
		GameState.upgrades["roomba"] = true
		get_tree().get_first_node_in_group("tank").ensure_roomba()
		SaveManager.save_game()
		_update_affordability(GameState.money)

func _update_affordability(total: int) -> void:
	if is_instance_valid(_roomba_button):
		var owned: bool = GameState.upgrades.get("roomba", false)
		_roomba_button.text = "Owned" if owned else "Buy Roomba"
		_roomba_button.disabled = owned or total < _roomba.cost
	for i in catalog.size():
		_buttons[i].disabled = total < catalog[i].price

func _buy(data: FishData) -> void:
	if get_tree().paused or Net.visiting() or not catalog.has(data):
		return
	if GameState.spend(data.price):
		Events.fish_bought.emit(data)
