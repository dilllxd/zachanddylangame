extends Control

func _ready() -> void:
	Events.money_changed.connect(_on_money_changed)
	_on_money_changed(GameState.money)
	if GameState.offline_earned > 0:
		var notice := Label.new()
		notice.text = "Welcome back! Roomba earned $%d" % GameState.offline_earned
		notice.position = Vector2(220, 24)
		notice.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
		add_child(notice)
		GameState.offline_earned = 0
		get_tree().create_timer(7.0, false).timeout.connect(notice.queue_free)

func _on_money_changed(total: int) -> void:
	$Money.text = "$%d" % total
