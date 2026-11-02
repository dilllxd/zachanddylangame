extends Control
## Compact dock; selected fish is the one you bring and can permanently gift.
var panel: PanelContainer
var name_edit: LineEdit
var room_edit: LineEdit
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
	var toggle := Button.new()
	toggle.text = "Visit tanks"
	toggle.position = Vector2(350, 20)
	toggle.pressed.connect(_toggle)
	add_child(toggle)
	panel = PanelContainer.new()
	panel.position = Vector2(350, 66)
	panel.custom_minimum_size = Vector2(320, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "A LITTLE COMPANY"
	box.add_child(title)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Your name"
	name_edit.max_length = 24
	name_edit.text = GameState.player_name
	name_edit.text_submitted.connect(func(value: String): Net.set_player_name(value))
	box.add_child(name_edit)
	host_button = _button(box, "Open tank", _host)
	var hint := Label.new()
	hint.text = "Or bring a fish to a friend's tank"
	box.add_child(hint)
	room_edit = LineEdit.new()
	room_edit.placeholder_text = "Room code"
	room_edit.max_length = 12
	box.add_child(room_edit)
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
	_refresh()

func _button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	box.add_child(button)
	return button

func _process(_delta: float) -> void:
	visible = not get_tree().paused
	if get_tree().paused:
		confirmation.hide()

func _toggle() -> void:
	if get_tree().paused:
		return
	panel.visible = not panel.visible
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
	Net.set_player_name(name_edit.text)
	Net.open_tank()

func _join() -> void:
	if not GameState.gift_outbox.is_empty():
		Net.set_player_name(name_edit.text)
		Net.visit(room_edit.text, null)
	elif choices.selected >= 0 and choices.selected < owned.size():
		Net.set_player_name(name_edit.text)
		Net.visit(room_edit.text, owned[choices.selected])

func _refresh() -> void:
	state.text = Net.status
	if not GameState.gift_outbox.is_empty():
		state.text += "\nPending gift saved. Revisit its host to finish delivery."
	host_button.disabled = not Net.mode.is_empty()
	join_button.disabled = not Net.mode.is_empty() or (owned.is_empty() and GameState.gift_outbox.is_empty())
	gift_button.visible = Net.visiting()
	gift_button.disabled = Net._selected == null or not GameState.gift_outbox.is_empty()
	leave_button.visible = not Net.mode.is_empty()
