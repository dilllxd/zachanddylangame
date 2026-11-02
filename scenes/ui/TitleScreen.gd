extends Control

func _ready() -> void:
	theme = Cozy.THEME
	Cozy.button_motion(self)
	var tagline := Cozy.label("A little water. A little wonder.",22,Color("#a0c9c3"))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Center/Menu.add_child(tagline)
	$Center/Menu.move_child(tagline,1)
	$Center/Menu/Play.text = "Enter your aquarium"
	$Center/Menu/Play.grab_focus()
	if not Account.username.is_empty():
		var switch := Button.new()
		switch.text = "Switch account (%s)" % Account.username
		switch.custom_minimum_size.y = 36
		switch.add_theme_font_size_override("font_size",16)
		switch.pressed.connect(func():
			Account.logout()
			get_tree().change_scene_to_file("res://scenes/ui/AccountScreen.tscn"))
		$Center/Menu.add_child(switch)
		$Center/Menu.move_child(switch,$Center/Menu/Quit.get_index())

func _on_play_pressed() -> void:
	var next := "res://scenes/main/Main.tscn" if Account.is_logged_in() else "res://scenes/ui/AccountScreen.tscn"
	get_tree().change_scene_to_file(next)

func _on_quit_pressed() -> void:
	get_tree().quit()
