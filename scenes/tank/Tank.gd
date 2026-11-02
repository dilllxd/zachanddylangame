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
	ensure_roomba()

func ensure_roomba() -> void:
	if GameState.upgrades.get("roomba", false) and not $Maintenance.has_node("Roomba"):
		$Maintenance.add_child(preload("res://scenes/feeder/Roomba.tscn").instantiate())

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

# Recompute owned candidates at click time; never trust stale UI counts.
func merge_candidates(data: FishData, tier: int) -> Array[Node]:
	var result: Array[Node] = []
	for fish in $Fishes.get_children():
		if not fish.has_meta("visitor") and not fish.is_queued_for_deletion() and fish.data == data and fish.tier == tier:
			result.append(fish)
	return result

func merge_fish(data: FishData, tier: int) -> Node:
	if get_tree().paused or Net.visiting() or not FishTier.valid(tier) or tier >= FishTier.MAX:
		return null
	var candidates := merge_candidates(data, tier)
	if candidates.size() < 3 or GameState.money < FishTier.fee(data, tier):
		return null
	var point := Vector2.ZERO
	var fullness := 0.0
	for i in 3:
		point += candidates[i].position
		fullness += candidates[i].fullness
	GameState.spend(FishTier.fee(data, tier))
	for i in 3:
		$Fishes.remove_child(candidates[i])
		candidates[i].queue_free()
	var fish := preload("res://scenes/fish/Fish.tscn").instantiate()
	fish.data = data
	fish.tier = tier + 1
	fish.position = point / 3.0
	$Fishes.add_child(fish)
	fish.fullness = fullness / 3.0
	var sprite: Sprite2D = fish.get_node("Sprite2D")
	var target := sprite.scale
	sprite.scale = target * 0.6
	fish.create_tween().tween_property(sprite, "scale", target, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SaveManager.save_game()
	return fish
