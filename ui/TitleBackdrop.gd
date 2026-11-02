extends Control
var clock := 0.0
var sprites: Array[Texture2D] = [preload("res://assets/fish/goldfish.png"),preload("res://assets/fish/bluefin.png"),preload("res://assets/fish/rosie.png")]
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
 clock += delta
 queue_redraw()
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("#103d49"))
 for i in 10:
  var x := fposmod(i*163.0+clock*(13+i*2),size.x+120)-60
  var y := size.y*(0.18+fmod(i*0.173,0.7))+sin(clock*0.7+i)*18
  draw_texture_rect(sprites[i%3],Rect2(Vector2(x,y),Vector2(90,90)),false,Color(1,1,1,0.38))
 for i in 24:
  var x := fmod(i*83.0+22,size.x)
  var y := size.y-fposmod(clock*18+i*61,size.y)
  draw_arc(Vector2(x,y),3+i%4,0,TAU,20,Color(0.6,0.9,0.85,0.14),1.0,true)
