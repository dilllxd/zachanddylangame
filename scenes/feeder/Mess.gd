extends Sprite2D
var floor_y := 390.0
func _ready() -> void:
	texture = preload("res://assets/feeder/mess.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	position.y = minf(position.y + 42.0 * delta, floor_y)
