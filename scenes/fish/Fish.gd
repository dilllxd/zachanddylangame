extends Node2D

@export var data: FishData
@export_range(0, 3) var tier: int = 0
@export var chase_mult: float = 2.2      # chase speed = swim_speed * this
@export var eat_distance: float = 10.0
@export var turn_rate: float = 5.0       # higher = snappier turns
@export var retarget_interval: float = 0.25

var fish_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
var tank: Node2D
@onready var hunger: Node = $Hunger
@onready var movement: Node = $Movement
@onready var seeker: Node = $FoodSeeker
@onready var bar: Node2D = $FullnessBar

# Public fullness property also lets tests and future save code set hunger.
var fullness: float:
	get: return hunger.fullness
	set(value): hunger.fullness = value

var _retarget_timer: float = 0.0

func is_hungry() -> bool:
	return hunger.is_hungry()

func _ready() -> void:
	tank = get_tree().get_first_node_in_group("tank")
	hunger.data = data
	movement.fish = self
	movement.tank = tank
	seeker.fish = self
	bar.fish = self
	if data and data.sprite:
		$Sprite2D.texture = data.sprite
	FishTier.style($Sprite2D, tier)
	_retarget_timer = randf() * retarget_interval
	await get_tree().process_frame
	if not tank.navigator.is_open(position):
		position = tank.navigator.random_open_point()
	movement.pick_wander_target()

func _process(delta: float) -> void:
	if movement.path_goal == Vector2.INF:
		return
	var speed: float = data.swim_speed if data else 50.0
	hunger.tick(delta)
	_retarget_timer -= delta
	var replan := false
	if _retarget_timer <= 0.0:
		_retarget_timer = retarget_interval
		seeker.update_food_target()
		replan = true
	var goal: Vector2
	var target_speed := speed
	if is_instance_valid(seeker.food_target):
		target_speed = speed * chase_mult
		if position.distance_to(seeker.food_target.position) < eat_distance + 4.0:
			eat(seeker.food_target)
			return
		goal = seeker.predicted_goal(target_speed)
	else:
		goal = movement.wander_target
		if position.distance_to(goal) < 8:
			movement.pick_wander_target()
			goal = movement.wander_target
	var steer_to: Vector2 = movement.next_waypoint(goal, replan)
	movement.steer(steer_to, target_speed, goal, delta)
	bar.tick(delta)

func eat(pellet: Node2D) -> void:
	hunger.feed(pellet.nutrition())
	var payout := roundi((FishTier.payout(data, tier) if data else 5) * pellet.payout_mult)
	var feeder: String = pellet.feeder
	pellet.eat()
	bar.show_after_eating()
	seeker.food_target = null
	Net.payout(self, payout, feeder)
	movement.pick_wander_target()
