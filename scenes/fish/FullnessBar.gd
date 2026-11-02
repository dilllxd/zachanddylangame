extends Node2D

var fish: Node2D
var show_timer: float = 0.0
const BAR_SIZE := Vector2(36, 5)
const BAR_OFFSET := Vector2(-18, -40)

func tick(delta: float) -> void:
	show_timer = max(show_timer - delta, 0.0)
	queue_redraw()

func show_after_eating() -> void:
	show_timer = 1.5

func _draw() -> void:
	if not fish.is_hungry() and show_timer <= 0.0:
		return
	draw_rect(Rect2(BAR_OFFSET - Vector2(1, 1), BAR_SIZE + Vector2(2, 2)), Color(0, 0, 0, 0.6))
	var col := Color.RED.lerp(Color.GREEN, fish.fullness)
	draw_rect(Rect2(BAR_OFFSET, Vector2(BAR_SIZE.x * fish.fullness, BAR_SIZE.y)), col)
