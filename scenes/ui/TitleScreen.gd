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

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
