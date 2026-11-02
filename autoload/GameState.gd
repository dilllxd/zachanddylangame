# money, owned fish, upgrades. single source of truth for numbers
extends Node

var money: int = 0

func _ready() -> void:
	Events.fish_fed.connect(_on_fish_fed)

func _on_fish_fed(fish, payout: int) -> void:
	add_money(payout)

func add_money(amount: int) -> void:
	money += amount
	Events.money_changed.emit(money)

func spend(amount: int) -> bool:
	if amount > money:
		return false
	add_money(-amount)
	return true
