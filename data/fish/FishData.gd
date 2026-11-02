class_name FishData
extends Resource

@export var name: String
@export var sprite: Texture2D
@export var price: int
## money earned each time this fish eats a pellet (manual feeding)
@export var pellet_value: int = 5
## fullness lost per second (fullness goes 0..1)
@export var hunger_rate: float = 0.02
## won't eat above this fullness, stops click spam
@export_range(0.0, 1.0) var hungry_below: float = 0.8
@export var swim_speed: float = 50.0
@export var growth_stages: Array[Texture2D]
