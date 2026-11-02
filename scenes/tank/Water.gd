extends ColorRect
func _ready() -> void:
 color = Color("#144958")
 mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
 for i in 32:
  var y := float(i) * size.y / 32.0
  draw_rect(Rect2(0,y,size.x,size.y/32.0+1), Color("#246676").lerp(Color("#103e50"),float(i)/32.0))
 for i in 8:
  var x := float(i)*128.0-60.0
  draw_colored_polygon(PackedVector2Array([Vector2(x,0),Vector2(x+26,0),Vector2(x+170,size.y),Vector2(x+95,size.y)]),Color(0.6,1,0.9,0.025))
 draw_style_box(_rim(), Rect2(Vector2.ZERO,size))
func _rim() -> StyleBoxFlat:
 var rim := StyleBoxFlat.new()
 rim.bg_color = Color.TRANSPARENT
 rim.set_border_width_all(4)
 rim.border_color = Color("#538b8b")
 rim.set_corner_radius_all(18)
 return rim
