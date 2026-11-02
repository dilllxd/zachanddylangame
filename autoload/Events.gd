# signal bus, no logic
extends Node

signal food_dropped(food: FoodData, position: Vector2)
signal fish_fed(fish, payout: int)
signal fish_bought(fish_data: FishData)
signal money_changed(total: int)
