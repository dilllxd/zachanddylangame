extends Node
func _ready() -> void:
 for control in $UI.get_children():
  if control is Control: control.theme = Cozy.THEME
 get_viewport().size_changed.connect(_layout)
 _layout()
 Cozy.button_motion($UI)
func _layout() -> void:
 var view := get_viewport().get_visible_rect().size
 var factor := minf((view.x - 80.0) / 800.0, (view.y - 200.0) / 450.0)
 $World/Tank.scale = Vector2.ONE * factor
 $World/Tank.position = Vector2((view.x - 800.0 * factor) / 2.0, 104.0)
