extends Sprite2D
## Three scraps become one recycled, half-value pellet.
const PIECES_PER_PELLET := 3
var collected := 0
var produced := 0
var direction := 1.0
var tank: Node2D
var cooldown := 0.0
func _ready() -> void:
	tank = get_parent().get_parent()
	texture = preload("res://assets/feeder/roomba.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(tank.bounds.get_center().x, tank.bounds.end.y - 8.0)
func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var target: Node2D
	var distance := INF
	for scrap in get_parent().get_node("Mess").get_children():
		if scrap.is_queued_for_deletion() or scrap.position.y < scrap.floor_y - 1.0:
			continue
		var d: float = absf(scrap.position.x - position.x)
		if d < distance:
			distance = d
			target = scrap
	if is_instance_valid(target):
		position.x = move_toward(position.x, target.position.x, 55.0 * delta)
		if absf(position.x - target.position.x) < 9.0 and cooldown <= 0.0:
			target.queue_free()
			collected += 1
			cooldown = 0.8
			if collected >= PIECES_PER_PELLET:
				collected -= PIECES_PER_PELLET
				produced += 1
				# Eject above the floor so fish can chase the recycled food.
				tank.drop_food(Vector2(position.x, position.y - 70.0), null, 0.5)
	else:
		position.x += direction * 18.0 * delta
		if position.x <= tank.bounds.position.x + 16.0 or position.x >= tank.bounds.end.x - 16.0:
			direction *= -1.0
	position.x = clampf(position.x, tank.bounds.position.x + 16.0, tank.bounds.end.x - 16.0)
