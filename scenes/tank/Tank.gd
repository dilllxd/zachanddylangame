extends Node2D

@export var bounds := Rect2(30, 30, 740, 360)
@export var pellet_scene: PackedScene = preload("res://scenes/food/FoodPellet.tscn")
@onready var navigator: Node2D = $Navigator

func _enter_tree() -> void:
	add_to_group("tank")

func _ready() -> void:
	Events.fish_bought.connect(_on_fish_bought)
	if not SaveManager.load_tank(self):
		var fish := preload("res://scenes/fish/Fish.tscn").instantiate()
		fish.name = "Goldy"
		fish.position = Vector2(150, 120)
		$Fishes.add_child(fish)

func floor_at(x: float, from_y: float) -> float:
	var top: float = navigator.decor_top(x)
	if top >= from_y and top < bounds.end.y:
		return top - 3.0
	return bounds.end.y

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := to_local(get_global_mouse_position())
		if navigator.is_open(p):
			if Net.visiting():
				Net.request_food(p)
			else:
				drop_food(p)
			get_viewport().set_input_as_handled()

func drop_food(p: Vector2, food: FoodData = null, payout_mult: float = 1.0, feeder: String = "") -> void:
	var pellet = pellet_scene.instantiate()
	pellet.position = p
	pellet.food = food
	pellet.feeder = feeder
	pellet.payout_mult = payout_mult
	pellet.floor_y = floor_at(p.x, p.y)
	$Food.add_child(pellet)
	Events.food_dropped.emit(food, p)


func _on_fish_bought(data: FishData) -> void:
	if Net.visiting():
		return
	var fish := preload("res://scenes/fish/Fish.tscn").instantiate()
	fish.data = data
	fish.position = navigator.random_open_point()
	$Fishes.add_child(fish)
	SaveManager.save_game()
