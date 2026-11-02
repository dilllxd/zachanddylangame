extends Control
## Login / sign up. Reached from the title screen when no session is active.
const MAIN := "res://scenes/main/Main.tscn"
const TITLE := "res://scenes/ui/TitleScreen.tscn"
var user_edit: LineEdit
var pass_edit: LineEdit
var remember: CheckBox
var status: Label
var login_button: Button
var signup_button: Button
var offline_button: Button
var resumed := false
var entering := false

func _ready() -> void:
	theme = Cozy.THEME
	var backdrop := Control.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_script(load("res://ui/TitleBackdrop.gd"))
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Cozy.label("Your aquarium", 32, Color("#ffd992"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := Cozy.label("Log in to keep your tank safe in the cloud.", 16, Color("#a0c9c3"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	user_edit = LineEdit.new()
	user_edit.placeholder_text = "Username"
	user_edit.max_length = 16
	user_edit.text = Account.username
	user_edit.text_submitted.connect(func(_t: String): pass_edit.grab_focus())
	box.add_child(user_edit)
	pass_edit = LineEdit.new()
	pass_edit.placeholder_text = "Password"
	pass_edit.secret = true
	pass_edit.max_length = 128
	pass_edit.text_submitted.connect(func(_t: String): _submit(false))
	box.add_child(pass_edit)
	remember = CheckBox.new()
	remember.text = "Remember me on this device"
	remember.button_pressed = true
	box.add_child(remember)
	login_button = _button(box, "Log in", func(): _submit(false))
	signup_button = _button(box, "Sign up", func(): _submit(true))
	offline_button = _button(box, "Play offline with saved tank", _offline)
	offline_button.visible = Account.has_offline_cache()
	_button(box, "Back", func(): get_tree().change_scene_to_file(TITLE))
	status = Cozy.label("", 15, Color("#ffb4a2"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	box.move_child(status, login_button.get_index())
	Account.changed.connect(_refresh)
	Cozy.button_motion(self)
	user_edit.grab_focus()
	_refresh()
	_try_resume()

func _button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	box.add_child(button)
	return button

func _try_resume() -> void:
	if resumed or Account.token.is_empty():
		return
	resumed = true
	if await Account.resume():
		_enter()

func _submit(sign_up: bool) -> void:
	if Account.busy:
		return
	var name := user_edit.text.strip_edges()
	if name.is_empty() or pass_edit.text.is_empty():
		status.text = "Enter a username and password."
		return
	if sign_up:
		Account.signup(name, pass_edit.text, remember.button_pressed)
	else:
		Account.login(name, pass_edit.text, remember.button_pressed)

func _refresh() -> void:
	if not is_inside_tree():
		return
	login_button.disabled = Account.busy
	signup_button.disabled = Account.busy
	offline_button.disabled = Account.busy
	status.text = Account.status
	if Account.is_logged_in():
		pass_edit.clear()
		_enter()

func _offline() -> void:
	Account.play_offline()
	_enter()

func _enter() -> void:
	if not entering and is_inside_tree() and get_tree().current_scene == self:
		entering = true
		get_tree().change_scene_to_file(MAIN)
