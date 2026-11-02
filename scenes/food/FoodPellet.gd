extends Node2D

@export var sink_speed: float = 30.0
var feeder: String = ""
var food: FoodData
var floor_y: float = 410.0  # set by Tank on spawn
## 1.0 = manual click, autofeeder will drop pellets with a lower multiplier
var payout_mult: float = 1.0
var claimed_by: Node = null  # stops every fish piling onto one pellet
## seconds a pellet lasts after landing before it dissolves (fades out the last 3s)
@export var lifetime: float = 20.0
var _rest_time := 0.0

func _ready() -> void:
	add_to_group("food")

func _process(delta: float) -> void:
	if position.y < floor_y:
		position.y = min(position.y + sink_speed * delta, floor_y)
	else:
		_rest_time += delta
		modulate.a = clamp((lifetime - _rest_time) / 3.0, 0.0, 1.0)
		if _rest_time >= lifetime:
			eat()

## where this pellet will be in t seconds (for leading the chase)
func predict(t: float) -> Vector2:
	return Vector2(position.x, min(position.y + sink_speed * t, floor_y))

func nutrition() -> float:
	return food.nutrition if food else 0.25

func eat() -> void:
	remove_from_group("food")
	queue_free()
