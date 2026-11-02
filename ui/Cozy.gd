class_name Cozy
extends RefCounted
const THEME = preload("res://ui/theme.tres")
static func button_motion(node: Node) -> void:
 for child in node.get_children():
  if child is Button and not child.has_meta("cozy"):
   child.set_meta("cozy", true)
   child.mouse_entered.connect(func():
    if is_instance_valid(child):
     child.pivot_offset = child.size * 0.5
     child.create_tween().tween_property(child, "scale", Vector2.ONE * 1.025, 0.12))
   child.mouse_exited.connect(func():
    if is_instance_valid(child): child.create_tween().tween_property(child, "scale", Vector2.ONE, 0.12))
  button_motion(child)
static func label(text: String, size: int = 19, color: Color = Color("#e5f3e7")) -> Label:
 var result := Label.new()
 result.text = text
 result.add_theme_font_size_override("font_size", size)
 result.add_theme_color_override("font_color", color)
 return result
