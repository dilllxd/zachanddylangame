extends Control

func _ready() -> void:
	Events.money_changed.connect(_on_money_changed)
	_on_money_changed(GameState.money)

func _on_money_changed(total: int) -> void:
	$Money.text = "$%d" % total
