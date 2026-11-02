extends Node

var data: FishData
var fullness: float = 0.5

func tick(delta: float) -> void:
	fullness = max(fullness - (data.hunger_rate if data else 0.02) * delta, 0.0)

func is_hungry() -> bool:
	return fullness < (data.hungry_below if data else 0.8)

func feed(amount: float) -> void:
	fullness = min(fullness + amount, 1.0)
