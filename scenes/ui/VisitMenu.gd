extends Control
## Compact dock; selected fish is the one you bring and can permanently gift.
var panel: PanelContainer
var name_edit: LineEdit
var room_list: VBoxContainer
var selected_room := ""
var selected_label: Label
var choices: OptionButton
var state: Label
var owned: Array[Node] = []
var host_button: Button
var join_button: Button
var leave_button: Button
var gift_button: Button
var confirmation: ConfirmationDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Cozy.THEME
	var toggle := Button.new()
	toggle.text = "Visit tanks"
	toggle.position = Vector2(350, 20)
	toggle.pressed.connect(_toggle)
	# Entry point lives in the shared dock.
	toggle.queue_free()
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -226
	panel.offset_right = 226
	panel.offset_top = -240
	panel.offset_bottom = 240
	panel.custom_minimum_size = Vector2(412, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "A little company"
	title.add_theme_font_size_override("font_size",28)
	_button(box, "Back to tank", func(): panel.hide(); Net.browse_rooms(false))
	box.add_child(title)
	name_edit = LineEdit.new()
	name_edit.editable = false
	name_edit.text = Account.username
	box.add_child(name_edit)
	host_button = _button(box, "Open tank", _host)
	var hint := Label.new()
	hint.text = "Open tanks nearby. Everyone is welcome."
	box.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 138)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	room_list = VBoxContainer.new()
	room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(room_list)
	selected_label = Label.new()
	selected_label.text = "Choose a tank, then a fish to bring"
	box.add_child(selected_label)
	choices = OptionButton.new()
	box.add_child(choices)
	join_button = _button(box, "Visit with selected fish", _join)
	gift_button = _button(box, "Gift brought fish...", func(): confirmation.popup_centered())
	leave_button = _button(box, "Leave / close tank", func(): Net.leave())
	state = Label.new()
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.custom_minimum_size.x = 300
	box.add_child(state)
	add_child(panel)
	panel.hide()
	confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Give your brought fish to this host permanently?"
	confirmation.confirmed.connect(func(): Net.gift())
	add_child(confirmation)
	Net.changed.connect(_refresh)
	Net.rooms_changed.connect(_rooms_refresh)
	_refresh()
	Cozy.button_motion(self)

func _button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	box.add_child(button)
	return button

func _process(_delta: float) -> void:
	visible = not get_tree().paused
	if panel.visible:
		panel.offset_top = -panel.size.y * 0.5
		panel.offset_bottom = panel.size.y * 0.5
	if get_tree().paused:
		confirmation.hide()

func _toggle() -> void:
	if get_tree().paused:
		return
	panel.visible = not panel.visible
	Net.browse_rooms(panel.visible)
	if panel.visible:
		owned.clear()
		choices.clear()
		var tank := Net.tank()
		if tank != null:
			for fish in tank.get_node("Fishes").get_children():
				if not fish.has_meta("visitor"):
					owned.append(fish)
					choices.add_item("%s #%d" % [FishTier.title(fish.data, fish.tier), owned.size()])
		_refresh()

func _host() -> void:
	Net.open_tank()

func _join() -> void:
	if not GameState.gift_outbox.is_empty():
		Net.visit(selected_room, null)
	elif choices.selected >= 0 and choices.selected < owned.size():
		Net.visit(selected_room, owned[choices.selected])

func _refresh() -> void:
	state.text = Net.status
	if not GameState.gift_outbox.is_empty():
		state.text += "\nPending gift saved. Revisit its host to finish delivery."
	host_button.disabled = not Net.mode.is_empty()
	join_button.disabled = selected_room.is_empty() or not Net.mode.is_empty() or (owned.is_empty() and GameState.gift_outbox.is_empty())
	gift_button.visible = Net.visiting()
	var can_gift: bool = Net.can_gift()
	gift_button.disabled = not can_gift or Net._selected == null or not GameState.gift_outbox.is_empty()
	gift_button.tooltip_text = "" if can_gift else "Keep at least one fish in your tank."
	if Net.visiting() and Net.owned_count() < 2:
		state.text += "\nKeep at least one fish in your tank."
	leave_button.visible = not Net.mode.is_empty()


func _rooms_refresh() -> void:
	for child in room_list.get_children():
		room_list.remove_child(child)
		child.queue_free()
	var found := false
	for room in Net.rooms:
		if not room is Dictionary:
			continue
		var room_code := str(room.get("code", ""))
		if room_code == Net.code and Net.mode == "host":
			continue
		if room_code == selected_room:
			found = true
		var row := HBoxContainer.new()
		room_list.add_child(row)
		var label := Label.new()
		label.text = "%s  |  %d fish  |  %d/8 visiting" % [
			str(room.get("name", "Player")).left(24),
			int(room.get("fish_count", 0)), int(room.get("visitor_count", 0))]
		label.add_theme_font_size_override("font_size", 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.custom_minimum_size.x = 240
		row.add_child(label)
		var join := Button.new()
		join.text = "Join"
		join.disabled = not Net.mode.is_empty() or int(room.get("visitor_count", 0)) >= 8
		join.pressed.connect(func():
			selected_room = room_code
			selected_label.text = "Bringing a fish to " + str(room.get("name", "Player")).left(24)
			_refresh())
		row.add_child(join)
	if not found:
		selected_room = ""
		selected_label.text = "Choose a tank, then a fish to bring"
	if room_list.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "No open tanks yet. Open yours!"
		room_list.add_child(empty)
	_refresh()

func _exit_tree() -> void:
	Net.browse_rooms(false)
