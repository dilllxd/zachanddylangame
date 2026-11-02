extends Control
var count_label: Label
var money_tween: Tween
func _ready() -> void:
 theme = Cozy.THEME
 var bar := PanelContainer.new()
 bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 bar.offset_left = 32
 bar.offset_right = -32
 bar.offset_top = 20
 bar.offset_bottom = 84
 add_child(bar)
 var row := HBoxContainer.new()
 bar.add_child(row)
 row.add_child(Cozy.label("FISHING IDLE",24,Color("#f5cc82")))
 var spacer := Control.new()
 spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(spacer)
 var money := $Money
 remove_child(money)
 row.add_child(money)
 money.name = "Money"
 money.text = "$0"
 money.add_theme_color_override("font_color",Color("#f5cc82"))
 count_label = Cozy.label("")
 row.add_child(count_label)
 Events.money_changed.connect(_on_money_changed)
 Events.fish_fed.connect(_fish_fed)
 set_meta("money_label", money)
 _on_money_changed(GameState.money)
 if GameState.offline_earned > 0:
  var popup := AcceptDialog.new()
  popup.title = "Welcome back"
  popup.dialog_text = "Your little ecosystem kept growing.\nRoomba earned $%d while you were away." % GameState.offline_earned
  add_child(popup)
  popup.popup_centered(Vector2i(460,180))
  GameState.offline_earned = 0
 set_meta("money_label", money)

func _process(_delta: float) -> void:
 var tank := get_tree().get_first_node_in_group("tank")
 if tank != null:
  count_label.text = "  /  %d fish" % tank.get_node("Fishes").get_child_count()
func _on_money_changed(total: int) -> void:
 var money: Label = get_meta("money_label", null)
 if money == null: return
 money.text = "$%s" % total
 money.pivot_offset = money.size * 0.5
 if money_tween: money_tween.kill()
 money.scale = Vector2.ONE * 1.12
 money_tween = create_tween()
 money_tween.tween_property(money,"scale",Vector2.ONE,0.22).set_trans(Tween.TRANS_BACK)
func _fish_fed(fish: Node, payout: int) -> void:
 if not is_instance_valid(fish) or payout <= 0: return
 var pop := Cozy.label("+$%d" % payout,22,Color("#ffe0a1"))
 pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
 pop.position = fish.get_global_transform_with_canvas().origin - Vector2(16,30)
 add_child(pop)
 var tween := create_tween().set_parallel()
 tween.tween_property(pop,"position:y",pop.position.y-52,1.0)
 tween.tween_property(pop,"modulate:a",0.0,1.0)
 tween.chain().tween_callback(pop.queue_free)
