extends Sprite2D
## A slow glass-edge scrubber. Three algae patches become one half-value pellet.
const PIECES_PER_PELLET := 3
var collected := 0
var produced := 0
var tank: Node2D
var algae: Node2D
var along := 0.0
var cooldown := 0.0
func _ready() -> void:
	tank = get_parent().get_parent()
	algae = get_parent().get_node("Algae")
	texture = preload("res://assets/feeder/roomba.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	along = algae.edge.size.x + algae.edge.size.y + algae.edge.size.x * 0.5
	position = algae.point_at(along)
func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var target: Node2D
	var distance := INF
	var travel := 1.0
	for patch in algae.get_children():
		if patch.is_queued_for_deletion():
			continue
		var diff: float = fposmod(float(patch.get_meta("along")) - along + algae.perimeter * 0.5, algae.perimeter) - algae.perimeter * 0.5
		if absf(diff) < distance:
			distance = absf(diff)
			travel = signf(diff)
			target = patch
	if is_instance_valid(target):
		along = fposmod(along + travel * minf(32.0 * delta, distance), algae.perimeter)
		if distance < 9.0 and cooldown <= 0.0:
			target.queue_free()
			collected += 1
			cooldown = 0.8
			if collected >= PIECES_PER_PELLET:
				collected -= PIECES_PER_PELLET
				produced += 1
				var drop: Vector2 = algae.point_at(along).move_toward(tank.bounds.get_center(), 65.0)
				tank.drop_food(drop, null, 0.5)
	else:
		along = fposmod(along + 16.0 * delta, algae.perimeter)
	var next: Vector2 = algae.point_at(along)
	var direction: Vector2 = next - position
	if direction.length_squared() > 0.001:
		rotation = direction.angle()
	position = next
