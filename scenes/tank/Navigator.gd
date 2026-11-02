extends Node2D

const CELL := 16
@export var fish_radius: float = 10.0
@export var debug_draw_grid: bool = false
var bounds: Rect2
var grid := AStarGrid2D.new()
var decor: Array = []
var surface := PackedFloat32Array()

func _ready() -> void:
	bounds = get_parent().bounds
	build_grid()

func build_grid() -> void:
	grid.region = Rect2i(0, 0, ceili(bounds.size.x / CELL), ceili(bounds.size.y / CELL))
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = bounds.position + Vector2(CELL, CELL) / 2.0
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	decor.clear()
	for d in get_tree().get_nodes_in_group("decor"):
		if d.blocks_fish and get_parent().is_ancestor_of(d):
			decor.append(d)
	# per column surface height, so slopes and narrow rock tops are exact
	surface.resize(grid.region.size.x)
	for x in grid.region.size.x:
		var cx := cell_to_point(Vector2i(x, 0)).x
		var top := INF
		for dx in [-fish_radius, 0.0, fish_radius]:  # pad sideways
			top = min(top, decor_top(cx + dx))
		surface[x] = top - fish_radius  # pad upward
		for y in grid.region.size.y:
			if cell_to_point(Vector2i(x, y)).y > surface[x]:
				grid.set_point_solid(Vector2i(x, y))
	queue_redraw()

## highest decor pixel at x (smaller y = higher), INF if none
func decor_top(x: float) -> float:
	var top := INF
	for d in decor:
		top = min(top, d.top_at(x, self))
	return top

func cell_to_point(c: Vector2i) -> Vector2:
	return bounds.position + Vector2(c) * CELL + Vector2(CELL, CELL) / 2.0

func point_to_cell(p: Vector2) -> Vector2i:
	var c := Vector2i(((p - bounds.position) / CELL).floor())
	return c.clamp(Vector2i.ZERO, grid.region.size - Vector2i.ONE)

func is_open(p: Vector2) -> bool:
	return bounds.has_point(p) and not grid.is_point_solid(point_to_cell(p))

## ignores the padding, just "is this inside actual rock pixels". used for the last bit of a food chase
func is_open_raw(p: Vector2) -> bool:
	return bounds.grow(4).has_point(p) and p.y < decor_top(p.x) - 2.0

## true if a fish can swim straight from a to b without touching decor
func line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := ceili(a.distance_to(b) / (CELL * 0.5))
	for i in range(1, steps + 1):
		if not is_open(a.lerp(b, float(i) / steps)):
			return false
	return true

func nearest_open_cell(c: Vector2i) -> Vector2i:
	if not grid.is_point_solid(c):
		return c
	for r in range(1, 12):
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				var n := c + Vector2i(x, y)
				if grid.is_in_boundsv(n) and not grid.is_point_solid(n):
					return n
	return c

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_open_cell(point_to_cell(from))
	var b := nearest_open_cell(point_to_cell(to))
	var pts := grid.get_point_path(a, b, true)
	if not pts.is_empty() and is_open(to):
		pts[pts.size() - 1] = to
	return pts

## closest swimmable spot to p, searching upward first (food sits on top of rocks)
func open_point_near(p: Vector2) -> Vector2:
	if is_open(p):
		return p
	for i in range(1, 40):
		var up := p + Vector2(0, -4 * i)
		if is_open(up):
			return up
	return cell_to_point(nearest_open_cell(point_to_cell(p)))

func random_open_point() -> Vector2:
	for i in 50:
		var p := Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
		if is_open(p):
			return p
	return bounds.get_center()

func _draw() -> void:
	if not debug_draw_grid:
		return
	for x in grid.region.size.x:
		for y in grid.region.size.y:
			if grid.is_point_solid(Vector2i(x, y)):
				draw_rect(Rect2(cell_to_point(Vector2i(x, y)) - Vector2(CELL, CELL) / 2.0, Vector2(CELL, CELL)), Color(1, 0, 0, 0.25))
