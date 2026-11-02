extends Node2D
## Glass-edge algae grows independently of feeding, even before buying a scrubber.
const CAP := 48
const GROW_SECONDS := 12.0
var elapsed := 0.0
var tank: Node2D
var edge: Rect2
var perimeter: float
func _ready() -> void:
	tank = get_parent().get_parent()
	edge = tank.bounds.grow(-8.0)
	perimeter = 2.0 * (edge.size.x + edge.size.y)
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= GROW_SECONDS:
		elapsed = fmod(elapsed, GROW_SECONDS)
		grow_patch()
func point_at(offset: float) -> Vector2:
	var d := fposmod(offset, perimeter)
	if d < edge.size.x:
		return edge.position + Vector2(d, 0)
	d -= edge.size.x
	if d < edge.size.y:
		return Vector2(edge.end.x, edge.position.y + d)
	d -= edge.size.y
	if d < edge.size.x:
		return edge.end - Vector2(d, 0)
	d -= edge.size.x
	return Vector2(edge.position.x, edge.end.y - d)
func grow_patch(offset: float = -1.0) -> Node2D:
	if get_child_count() >= CAP:
		return null
	var along := randf() * perimeter if offset < 0.0 else fposmod(offset, perimeter)
	var patch := Polygon2D.new()
	patch.polygon = PackedVector2Array([Vector2(-10,-3),Vector2(-6,-7),Vector2(0,-5),Vector2(5,-8),Vector2(11,-2),Vector2(8,5),Vector2(1,7),Vector2(-8,5)])
	patch.color = Color(0.25, 0.55, 0.2, 0.55)
	patch.position = point_at(along)
	patch.scale = Vector2.ONE * randf_range(0.7, 1.3)
	patch.set_meta("along", along)
	add_child(patch)
	return patch
