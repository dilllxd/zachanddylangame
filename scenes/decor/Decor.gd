extends Node2D
## put this on any tank decoration with a Sprite2D child named Sprite2D
## collision follows the actual pixels: for every x, everything below the art's top edge is solid

## off for now, all decor is cosmetic. flip on per item later if we want solid props
@export var blocks_fish := false

var _img: Image

func _enter_tree() -> void:
	add_to_group("decor")

func _ensure_img() -> void:
	if _img == null:
		_img = $Sprite2D.texture.get_image()
		if _img.is_compressed():
			_img.decompress()

## top of the visible art at tank-space x, or INF if the art doesn't cover x
func top_at(x: float, space: Node2D) -> float:
	_ensure_img()
	var s: Sprite2D = $Sprite2D
	var r := s.get_rect()
	var local := s.to_local(space.to_global(Vector2(x, 0)))
	var px := int(floor(local.x - r.position.x))
	if px < 0 or px >= _img.get_width():
		return INF
	for py in _img.get_height():
		if _img.get_pixel(px, py).a > 0.5:
			return space.to_local(s.to_global(r.position + Vector2(px, py))).y
	return INF

## rough box for grid building, tank space
func get_bounds(space: Node2D) -> Rect2:
	var s: Sprite2D = $Sprite2D
	var r := s.get_rect()
	var a := space.to_local(s.to_global(r.position))
	var b := space.to_local(s.to_global(r.end))
	return Rect2(a, b - a).abs()
